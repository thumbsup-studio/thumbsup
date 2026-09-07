#!/usr/bin/env node
import { App } from 'aws-cdk-lib';
import { UpdatesServerStack } from '../lib/updates-server-stack.js';

const app = new App();

new UpdatesServerStack(app, 'ThumbsupUpdatesServer', {
  stackName: 'ThumbsupUpdatesServer',
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: 'ap-northeast-2',
  },
});
