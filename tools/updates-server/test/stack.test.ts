import { App } from 'aws-cdk-lib';
import { Match, Template } from 'aws-cdk-lib/assertions';
import { describe, expect, it } from 'vitest';
import { UpdatesServerStack } from '../lib/updates-server-stack.js';

function template(): Template {
  const app = new App();
  const stack = new UpdatesServerStack(app, 'TestStack', {
    env: { account: '111122223333', region: 'ap-northeast-2' },
  });
  return Template.fromStack(stack);
}

describe('UpdatesServerStack', () => {
  it('keeps the artifact bucket private, encrypted, versioned, and retained', () => {
    template().hasResource('AWS::S3::Bucket', {
      DeletionPolicy: 'Retain',
      UpdateReplacePolicy: 'Retain',
      Properties: {
        BucketName: 'thumbsup-mobile-artifacts',
        VersioningConfiguration: { Status: 'Enabled' },
        LifecycleConfiguration: {
          Rules: [
            {
              Id: 'ExpirePullRequestUpdates',
              Prefix: 'updates/pr-',
              ExpirationInDays: 30,
              NoncurrentVersionExpiration: { NoncurrentDays: 30 },
              Status: 'Enabled',
            },
            {
              Id: 'ExpireTelemetry',
              Prefix: 'telemetry/',
              ExpirationInDays: 30,
              NoncurrentVersionExpiration: { NoncurrentDays: 30 },
              Status: 'Enabled',
            },
          ],
        },
        PublicAccessBlockConfiguration: {
          BlockPublicAcls: true,
          BlockPublicPolicy: true,
          IgnorePublicAcls: true,
          RestrictPublicBuckets: true,
        },
      },
    });
  });

  it('isolates manifest capacity and caps telemetry with reserved concurrency', () => {
    const synthesized = template();
    synthesized.hasResourceProperties('AWS::Lambda::Function', {
      Runtime: 'nodejs22.x',
      Environment: { Variables: { ARTIFACTS_BUCKET: Match.anyValue() } },
    });
    synthesized.hasResourceProperties('AWS::Lambda::Url', { AuthType: 'AWS_IAM' });
    const functions = synthesized.findResources('AWS::Lambda::Function');
    expect(Object.keys(functions)).toHaveLength(2);
    const manifest = Object.entries(functions).find(([id]) => id.startsWith('ManifestHandler'))?.[1];
    const telemetry = Object.entries(functions).find(([id]) => id.startsWith('TelemetryHandler'))?.[1];
    expect(manifest?.Properties.ReservedConcurrentExecutions).toBe(5);
    expect(telemetry?.Properties.ReservedConcurrentExecutions).toBe(1);
  });

  it('routes only manifest requests to Lambda and makes update assets immutable', () => {
    const distributions = template().findResources('AWS::CloudFront::Distribution');
    const distribution = Object.values(distributions)[0];
    const behaviors = distribution.Properties.DistributionConfig.CacheBehaviors as Array<{
      PathPattern: string;
      CachePolicyId: string;
      ResponseHeadersPolicyId?: unknown;
    }>;

    expect(behaviors.find((item) => item.PathPattern === '/api/manifest*')).toMatchObject({
      CachePolicyId: '4135ea2d-6df8-44a3-9df3-4b5a84be39ad',
    });
    expect(behaviors.find((item) => item.PathPattern === '/api/telemetry/*')).toMatchObject({
      CachePolicyId: '4135ea2d-6df8-44a3-9df3-4b5a84be39ad',
      AllowedMethods: ['GET', 'HEAD', 'OPTIONS', 'PUT', 'PATCH', 'POST', 'DELETE'],
    });
    expect(behaviors.find((item) => item.PathPattern === '/updates/*')?.ResponseHeadersPolicyId).toBeTruthy();
    template().hasResourceProperties('AWS::CloudFront::ResponseHeadersPolicy', {
      ResponseHeadersPolicyConfig: {
        CustomHeadersConfig: {
          Items: [{
            Header: 'Cache-Control',
            Override: true,
            Value: 'public, max-age=31536000, immutable',
          }],
        },
      },
    });
  });

  it('allows the telemetry Lambda to write only under telemetry', () => {
    const policies = template().findResources('AWS::IAM::Policy');
    const statements = Object.values(policies).flatMap(
      (policy) => policy.Properties.PolicyDocument.Statement as Array<Record<string, unknown>>,
    );
    const write = statements.find((statement) => statement.Action === 's3:PutObject');
    expect(write).toMatchObject({ Action: 's3:PutObject', Effect: 'Allow' });
    expect(JSON.stringify(write?.Resource)).toContain('telemetry/*');
  });
  it('creates two GitHub OIDC roles scoped to nonprod and production prefixes', () => {
    const roles = template().findResources('AWS::IAM::Role');
    const byName = (name: string) =>
      Object.values(roles).find((role: any) => role.Properties?.RoleName === name) as any;
    const nonprod = byName('thumbsup-mobile-nonprod');
    const production = byName('thumbsup-mobile-production');
    expect(nonprod).toBeDefined();
    expect(production).toBeDefined();

    const trust = (role: any) => role.Properties.AssumeRolePolicyDocument.Statement[0];
    expect(trust(nonprod).Action).toBe('sts:AssumeRoleWithWebIdentity');
    expect(trust(nonprod).Condition.StringEquals['token.actions.githubusercontent.com:sub']).toEqual([
      'repo:thumbsup-studio/thumbsup:environment:mobile-staging-publish',
      'repo:thumbsup-studio/thumbsup:environment:mobile-staging-cleanup',
      'repo:thumbsup-studio/thumbsup:ref:refs/heads/main',
    ]);
    expect(trust(production).Condition.StringEquals['token.actions.githubusercontent.com:sub']).toEqual([
      'repo:thumbsup-studio/thumbsup:environment:mobile-production',
    ]);
    expect(trust(production).Condition.StringEquals['token.actions.githubusercontent.com:aud']).toBe('sts.amazonaws.com');

    const policies = Object.values(template().findResources('AWS::IAM::Policy')) as any[];
    const policyFor = (roleLogicalId: string) =>
      policies.find((policy) => JSON.stringify(policy.Properties.Roles).includes(roleLogicalId));
    const nonprodStatements = policyFor('GitHubNonprodRole').Properties.PolicyDocument.Statement as any[];
    const productionStatements = policyFor('GitHubProductionRole').Properties.PolicyDocument.Statement as any[];
    const text = (statements: any[]) => JSON.stringify(statements);

    expect(text(nonprodStatements)).toContain('updates/pr-*');
    expect(text(nonprodStatements)).toContain('updates/staging/*');
    expect(text(nonprodStatements)).toContain('binaries/*');
    expect(text(nonprodStatements)).not.toContain('updates/production');
    expect(nonprodStatements.find((s) => s.Sid === 'DeletePullRequestUpdatesOnly').Resource).toBeDefined();

    expect(text(productionStatements)).toContain('updates/production/*');
    expect(text(productionStatements)).not.toContain('updates/pr-');
    expect(productionStatements.some((s) => JSON.stringify(s.Action).includes('DeleteObject'))).toBe(false);
    expect(text(productionStatements)).not.toContain('ssm:');
  });
});
