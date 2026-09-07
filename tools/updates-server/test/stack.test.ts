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

  it('uses a Node.js 22 Lambda and IAM-authenticated function URL', () => {
    const synthesized = template();
    synthesized.hasResourceProperties('AWS::Lambda::Function', {
      Runtime: 'nodejs22.x',
      Environment: { Variables: { ARTIFACTS_BUCKET: Match.anyValue() } },
    });
    synthesized.hasResourceProperties('AWS::Lambda::Url', { AuthType: 'AWS_IAM' });
    synthesized.hasResourceProperties('AWS::Lambda::Function', {
      ReservedConcurrentExecutions: 5,
      Environment: { Variables: { ARTIFACTS_BUCKET: Match.anyValue() } },
    });
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
});
