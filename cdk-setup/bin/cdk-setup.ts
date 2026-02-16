#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { CdkSetupStack } from '../lib/cdk-setup-stack';

const app = new cdk.App();

new CdkSetupStack(app, 'CdkSetupStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION,
  },
  description: 'CDKセキュリティセットアップ - Permissions BoundaryとDeny Policyを作成',
});
