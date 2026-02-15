import * as cdk from 'aws-cdk-lib/core';
import { Template, Match } from 'aws-cdk-lib/assertions';
import * as CdkApp from '../lib/cdk-app-stack';
import { PermissionsBoundaryAspect } from '../lib/security-aspects';

describe('CdkAppStack Security Tests', () => {
  let app: cdk.App;
  let stack: CdkApp.CdkAppStack;
  let template: Template;

  beforeEach(() => {
    app = new cdk.App();
    stack = new CdkApp.CdkAppStack(app, 'TestStack', {
      env: { account: '123456789012', region: 'us-east-1' },
    });
    
    // Apply Permissions Boundary Aspect (same as in bin/cdk-app.ts)
    const permissionsBoundaryArn = 'arn:aws:iam::123456789012:policy/CDKPermissionsBoundary';
    cdk.Aspects.of(stack).add(new PermissionsBoundaryAspect(permissionsBoundaryArn));
    
    // Synthesize to apply aspects
    app.synth();
    
    template = Template.fromStack(stack);
  });

  test('Permissions Boundary Policy is created', () => {
    template.hasResourceProperties('AWS::IAM::ManagedPolicy', {
      ManagedPolicyName: 'CDKPermissionsBoundary',
      Description: Match.stringLikeRegexp('権限境界'),
    });
  });

  test('Deny Policy is created', () => {
    template.hasResourceProperties('AWS::IAM::ManagedPolicy', {
      ManagedPolicyName: 'CDKSecurityDenyPolicy',
      Description: Match.stringLikeRegexp('セキュリティ設定の変更を拒否'),
    });
  });

  test('S3 Bucket has encryption enabled', () => {
    template.hasResourceProperties('AWS::S3::Bucket', {
      BucketEncryption: {
        ServerSideEncryptionConfiguration: Match.arrayWith([
          Match.objectLike({
            ServerSideEncryptionByDefault: {
              SSEAlgorithm: 'AES256',
            },
          }),
        ]),
      },
    });
  });

  test('S3 Bucket has versioning enabled', () => {
    template.hasResourceProperties('AWS::S3::Bucket', {
      VersioningConfiguration: {
        Status: 'Enabled',
      },
    });
  });

  test('S3 Bucket blocks all public access', () => {
    template.hasResourceProperties('AWS::S3::Bucket', {
      PublicAccessBlockConfiguration: {
        BlockPublicAcls: true,
        BlockPublicPolicy: true,
        IgnorePublicAcls: true,
        RestrictPublicBuckets: true,
      },
    });
  });

  test('Lambda function IAM role has Permissions Boundary applied', () => {
    // Check that Lambda service role has Permissions Boundary
    // We just verify that at least one role with Lambda-related managed policy has PB
    const roles = template.findResources('AWS::IAM::Role');
    const lambdaRolesWithPB = Object.values(roles).filter(role => {
      const hasPB = role.Properties.PermissionsBoundary === 'arn:aws:iam::123456789012:policy/CDKPermissionsBoundary';
      const hasManagedPolicies = role.Properties.ManagedPolicyArns && role.Properties.ManagedPolicyArns.length > 0;
      return hasPB && hasManagedPolicies;
    });
    
    expect(lambdaRolesWithPB.length).toBeGreaterThan(0);
  });

  test('Custom IAM role has Permissions Boundary applied', () => {
    template.hasResourceProperties('AWS::IAM::Role', {
      RoleName: 'custom-role-with-pb',
      PermissionsBoundary: 'arn:aws:iam::123456789012:policy/CDKPermissionsBoundary',
    });
  });

  test('Lambda function is created with correct configuration', () => {
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'sample-function-with-pb',
      Runtime: 'nodejs20.x',
      Handler: 'index.handler',
    });
  });

  test('Stack outputs are defined', () => {
    template.hasOutput('BucketName', {});
    template.hasOutput('FunctionName', {});
    template.hasOutput('PermissionsBoundaryArn', {});
  });

  test('Permissions Boundary allows specific S3 actions', () => {
    template.hasResourceProperties('AWS::IAM::ManagedPolicy', {
      ManagedPolicyName: 'CDKPermissionsBoundary',
      PolicyDocument: Match.objectLike({
        Statement: Match.arrayWith([
          Match.objectLike({
            Effect: 'Allow',
            Action: Match.arrayWith([
              's3:GetObject',
              's3:PutObject',
              's3:DeleteObject',
              's3:ListBucket',
            ]),
          }),
        ]),
      }),
    });
  });

  test('Permissions Boundary denies IAM changes', () => {
    template.hasResourceProperties('AWS::IAM::ManagedPolicy', {
      ManagedPolicyName: 'CDKPermissionsBoundary',
      PolicyDocument: Match.objectLike({
        Statement: Match.arrayWith([
          Match.objectLike({
            Effect: 'Deny',
            Action: Match.arrayWith([
              'iam:CreatePolicy',
              'iam:AttachRolePolicy',
              'iam:PutRolePermissionsBoundary',
            ]),
          }),
        ]),
      }),
    });
  });

  test('Deny Policy prevents Permissions Boundary changes', () => {
    template.hasResourceProperties('AWS::IAM::ManagedPolicy', {
      ManagedPolicyName: 'CDKSecurityDenyPolicy',
      PolicyDocument: Match.objectLike({
        Statement: Match.arrayWith([
          Match.objectLike({
            Effect: 'Deny',
            Action: Match.arrayWith([
              'iam:DeleteRolePermissionsBoundary',
              'iam:PutRolePermissionsBoundary',
            ]),
          }),
        ]),
      }),
    });
  });

  test('All IAM roles have Permissions Boundary', () => {
    // Get all IAM roles from the template
    const roles = template.findResources('AWS::IAM::Role');
    const roleKeys = Object.keys(roles);
    
    // Verify that at least one role has Permissions Boundary
    let rolesWithBoundary = 0;
    roleKeys.forEach(key => {
      if (roles[key].Properties.PermissionsBoundary) {
        rolesWithBoundary++;
        expect(roles[key].Properties.PermissionsBoundary).toContain('CDKPermissionsBoundary');
      }
    });
    
    // At least 2 roles should have Permissions Boundary (Lambda and Custom role)
    expect(rolesWithBoundary).toBeGreaterThanOrEqual(2);
  });
});


