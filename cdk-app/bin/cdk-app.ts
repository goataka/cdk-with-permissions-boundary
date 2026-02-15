#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib/core';
import { CdkAppStack } from '../lib/cdk-app-stack';
import { 
  PermissionsBoundaryAspect, 
  IamRoleValidationAspect, 
  S3SecurityAspect 
} from '../lib/security-aspects';

const app = new cdk.App();

// スタックの作成
const stack = new CdkAppStack(app, 'CdkAppStack', {
  env: { 
    account: process.env.CDK_DEFAULT_ACCOUNT, 
    region: process.env.CDK_DEFAULT_REGION 
  },
  description: 'CDK with Permissions Boundary サンプルスタック',
});

// Permissions Boundary Aspectの適用
// 注意: 実際の運用では、事前に作成したPermissions Boundary ポリシーのARNを指定
const permissionsBoundaryArn = process.env.PERMISSIONS_BOUNDARY_ARN || 
  `arn:aws:iam::${process.env.CDK_DEFAULT_ACCOUNT}:policy/CDKPermissionsBoundary`;

cdk.Aspects.of(stack).add(new PermissionsBoundaryAspect(permissionsBoundaryArn));

// IAMロール検証Aspectの適用
cdk.Aspects.of(stack).add(new IamRoleValidationAspect());

// S3セキュリティ検証Aspectの適用
cdk.Aspects.of(stack).add(new S3SecurityAspect());

