import { CfnOutput, Duration, RemovalPolicy, Stack, type StackProps } from 'aws-cdk-lib';
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront';
import * as origins from 'aws-cdk-lib/aws-cloudfront-origins';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as nodejs from 'aws-cdk-lib/aws-lambda-nodejs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import type { Construct } from 'constructs';

export class UpdatesServerStack extends Stack {
  constructor(scope: Construct, id: string, props: StackProps = {}) {
    super(scope, id, props);

    const artifacts = new s3.Bucket(this, 'Artifacts', {
      bucketName: 'thumbsup-mobile-artifacts',
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      versioned: true,
      lifecycleRules: [
        {
          id: 'ExpirePullRequestUpdates',
          prefix: 'updates/pr-',
          expiration: Duration.days(30),
          noncurrentVersionExpiration: Duration.days(30),
        },
        {
          id: 'ExpireTelemetry',
          prefix: 'telemetry/',
          expiration: Duration.days(30),
          noncurrentVersionExpiration: Duration.days(30),
        },
      ],
      removalPolicy: RemovalPolicy.RETAIN,
      autoDeleteObjects: false,
    });

    const manifest = new nodejs.NodejsFunction(this, 'ManifestHandler', {
      runtime: lambda.Runtime.NODEJS_22_X,
      entry: new URL('../src/manifest.ts', import.meta.url).pathname,
      handler: 'handler',
      timeout: Duration.seconds(10),
      memorySize: 256,
      reservedConcurrentExecutions: 5,
      bundling: {
        minify: true,
        sourceMap: true,
        target: 'node22',
      },
      environment: {
        ARTIFACTS_BUCKET: artifacts.bucketName,
        SIGNING_PRIVATE_KEY_PARAMETER: '/thumbsup/prod/updates-signing-private-key',
        SIGNING_KEY_ID: 'main',
      },
    });

    manifest.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ['s3:GetObject'],
        resources: [
          artifacts.arnForObjects('channels/index.json'),
          artifacts.arnForObjects('updates/*'),
        ],
      }),
    );
    const signingParameterArn = Stack.of(this).formatArn({
      service: 'ssm',
      resource: 'parameter',
      resourceName: 'thumbsup/prod/updates-signing-private-key',
    });
    manifest.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ['ssm:GetParameter'],
        resources: [signingParameterArn],
      }),
    );
    manifest.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ['kms:Decrypt'],
        resources: ['*'],
        conditions: {
          StringEquals: {
            'kms:ViaService': `ssm.${this.region}.amazonaws.com`,
            'kms:EncryptionContext:PARAMETER_ARN': signingParameterArn,
          },
        },
      }),
    );

    const functionUrl = manifest.addFunctionUrl({
      authType: lambda.FunctionUrlAuthType.AWS_IAM,
      invokeMode: lambda.InvokeMode.BUFFERED,
    });

    const telemetry = new nodejs.NodejsFunction(this, 'TelemetryHandler', {
      runtime: lambda.Runtime.NODEJS_22_X,
      entry: new URL('../src/telemetry.ts', import.meta.url).pathname,
      handler: 'handler',
      timeout: Duration.seconds(10),
      memorySize: 256,
      reservedConcurrentExecutions: 1,
      bundling: {
        minify: true,
        sourceMap: true,
        target: 'node22',
      },
      environment: { ARTIFACTS_BUCKET: artifacts.bucketName },
    });
    telemetry.addToRolePolicy(new iam.PolicyStatement({
      actions: ['s3:PutObject'],
      resources: [artifacts.arnForObjects('telemetry/*')],
    }));
    const telemetryFunctionUrl = telemetry.addFunctionUrl({
      authType: lambda.FunctionUrlAuthType.AWS_IAM,
      invokeMode: lambda.InvokeMode.BUFFERED,
    });

    const preserveViewerHost = new cloudfront.Function(this, 'PreserveViewerHost', {
      code: cloudfront.FunctionCode.fromInline(`function handler(event) {
  var request = event.request;
  request.headers['x-forwarded-host'] = { value: request.headers.host.value };
  return request;
}`),
      runtime: cloudfront.FunctionRuntime.JS_2_0,
    });

    const distribution = new cloudfront.Distribution(this, 'Distribution', {
      defaultBehavior: {
        origin: origins.S3BucketOrigin.withOriginAccessControl(artifacts),
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        allowedMethods: cloudfront.AllowedMethods.ALLOW_GET_HEAD_OPTIONS,
        cachePolicy: cloudfront.CachePolicy.CACHING_DISABLED,
      },
      additionalBehaviors: {
        '/api/telemetry/*': {
          origin: origins.FunctionUrlOrigin.withOriginAccessControl(telemetryFunctionUrl),
          viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.HTTPS_ONLY,
          allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL,
          cachePolicy: cloudfront.CachePolicy.CACHING_DISABLED,
          originRequestPolicy: cloudfront.OriginRequestPolicy.ALL_VIEWER_EXCEPT_HOST_HEADER,
        },
        '/api/manifest*': {
          origin: origins.FunctionUrlOrigin.withOriginAccessControl(functionUrl),
          viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.HTTPS_ONLY,
          allowedMethods: cloudfront.AllowedMethods.ALLOW_GET_HEAD_OPTIONS,
          cachePolicy: cloudfront.CachePolicy.CACHING_DISABLED,
          originRequestPolicy: cloudfront.OriginRequestPolicy.ALL_VIEWER_EXCEPT_HOST_HEADER,
          functionAssociations: [
            {
              function: preserveViewerHost,
              eventType: cloudfront.FunctionEventType.VIEWER_REQUEST,
            },
          ],
        },
        '/updates/*': {
          origin: origins.S3BucketOrigin.withOriginAccessControl(artifacts),
          viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.HTTPS_ONLY,
          allowedMethods: cloudfront.AllowedMethods.ALLOW_GET_HEAD_OPTIONS,
          cachePolicy: cloudfront.CachePolicy.CACHING_OPTIMIZED,
          responseHeadersPolicy: new cloudfront.ResponseHeadersPolicy(this, 'ImmutableAssets', {
            customHeadersBehavior: {
              customHeaders: [
                {
                  header: 'Cache-Control',
                  value: 'public, max-age=31536000, immutable',
                  override: true,
                },
              ],
            },
          }),
        },
      },
      priceClass: cloudfront.PriceClass.PRICE_CLASS_200,
      httpVersion: cloudfront.HttpVersion.HTTP2_AND_3,
    });

    // GitHub Actions가 OIDC로 빌리는 역할 두 개. 승인자가 있는 production만 분리한다.
    const githubRepository = 'thumbsup-studio/thumbsup';
    const githubRepositoryId = '1289852286';
    const githubProvider = iam.OpenIdConnectProvider.fromOpenIdConnectProviderArn(
      this,
      'GitHubOidcProvider',
      Stack.of(this).formatArn({
        service: 'iam',
        region: '',
        resource: 'oidc-provider',
        resourceName: 'token.actions.githubusercontent.com',
      }),
    );
    const githubPrincipal = (subjects: string[]): iam.WebIdentityPrincipal =>
      new iam.WebIdentityPrincipal(githubProvider.openIdConnectProviderArn, {
        StringEquals: {
          'token.actions.githubusercontent.com:aud': 'sts.amazonaws.com',
          'token.actions.githubusercontent.com:repository_id': githubRepositoryId,
          'token.actions.githubusercontent.com:sub': subjects,
        },
      });

    const nonprodRole = new iam.Role(this, 'GitHubNonprodRole', {
      roleName: 'thumbsup-mobile-nonprod',
      description: 'PR 번들 publish·cleanup, staging OTA, 바이너리 업로드용 GitHub Actions 역할',
      maxSessionDuration: Duration.hours(1),
      assumedBy: githubPrincipal([
        `repo:${githubRepository}:environment:mobile-staging-publish`,
        `repo:${githubRepository}:environment:mobile-staging-cleanup`,
        `repo:${githubRepository}:ref:refs/heads/main`,
      ]),
    });
    nonprodRole.addToPolicy(new iam.PolicyStatement({
      sid: 'ChannelIndexReadWrite',
      actions: ['s3:GetObject', 's3:PutObject'],
      resources: [artifacts.arnForObjects('channels/index.json')],
    }));
    nonprodRole.addToPolicy(new iam.PolicyStatement({
      sid: 'PublishNonprodUpdatesAndBinaries',
      actions: ['s3:PutObject'],
      resources: [
        artifacts.arnForObjects('updates/pr-*'),
        artifacts.arnForObjects('updates/staging/*'),
        artifacts.arnForObjects('binaries/*'),
      ],
    }));
    nonprodRole.addToPolicy(new iam.PolicyStatement({
      sid: 'ReadBinaries',
      actions: ['s3:GetObject'],
      resources: [artifacts.arnForObjects('binaries/*')],
    }));
    nonprodRole.addToPolicy(new iam.PolicyStatement({
      sid: 'DeletePullRequestUpdatesOnly',
      actions: ['s3:DeleteObject'],
      resources: [artifacts.arnForObjects('updates/pr-*')],
    }));
    nonprodRole.addToPolicy(new iam.PolicyStatement({
      sid: 'ListNonprodPrefixesOnly',
      actions: ['s3:ListBucket'],
      resources: [artifacts.bucketArn],
      conditions: { StringLike: { 's3:prefix': ['updates/pr-*', 'updates/staging/*'] } },
    }));

    const productionRole = new iam.Role(this, 'GitHubProductionRole', {
      roleName: 'thumbsup-mobile-production',
      description: 'RC 검증과 production OTA 승격·롤백용 GitHub Actions 역할',
      maxSessionDuration: Duration.hours(1),
      assumedBy: githubPrincipal([`repo:${githubRepository}:environment:mobile-production`]),
    });
    productionRole.addToPolicy(new iam.PolicyStatement({
      sid: 'ChannelIndexReadWrite',
      actions: ['s3:GetObject', 's3:PutObject'],
      resources: [artifacts.arnForObjects('channels/index.json')],
    }));
    productionRole.addToPolicy(new iam.PolicyStatement({
      sid: 'ReadVerifiedStagingArtifacts',
      actions: ['s3:GetObject'],
      resources: [
        artifacts.arnForObjects('updates/staging/*'),
        artifacts.arnForObjects('binaries/staging/*'),
      ],
    }));
    productionRole.addToPolicy(new iam.PolicyStatement({
      sid: 'PromoteToProduction',
      actions: ['s3:PutObject'],
      resources: [artifacts.arnForObjects('updates/production/*')],
    }));
    productionRole.addToPolicy(new iam.PolicyStatement({
      sid: 'ListStagingUpdatesOnly',
      actions: ['s3:ListBucket'],
      resources: [artifacts.bucketArn],
      conditions: { StringLike: { 's3:prefix': 'updates/staging/*' } },
    }));

    new CfnOutput(this, 'ArtifactsBucketName', { value: artifacts.bucketName });
    new CfnOutput(this, 'UpdatesBaseUrl', {
      value: `https://${distribution.distributionDomainName}`,
    });
    new CfnOutput(this, 'NonprodRoleArn', { value: nonprodRole.roleArn });
    new CfnOutput(this, 'ProductionRoleArn', { value: productionRole.roleArn });
  }
}
