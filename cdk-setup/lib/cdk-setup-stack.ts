import * as cdk from 'aws-cdk-lib';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

/**
 * CDKセキュリティセットアップスタック
 * 
 * このスタックは管理者が最初にデプロイします。
 * Permissions BoundaryとDeny Policyを作成し、
 * 開発者がデプロイするアプリケーションから参照されます。
 */
export class CdkSetupStack extends cdk.Stack {
  public readonly permissionsBoundary: iam.ManagedPolicy;
  public readonly denyPolicy: iam.ManagedPolicy;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Permissions Boundary ポリシーの作成
    this.permissionsBoundary = new iam.ManagedPolicy(this, 'PermissionsBoundary', {
      managedPolicyName: 'CDKPermissionsBoundary',
      description: 'CDKで作成されるIAMロールに適用される権限境界',
      statements: [
        // 許可する操作を定義（例：S3、Lambda、CloudWatch Logs）
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            // S3 操作
            's3:GetObject',
            's3:PutObject',
            's3:DeleteObject',
            's3:ListBucket',
            // Lambda 操作
            'lambda:InvokeFunction',
            'lambda:GetFunction',
            // CloudWatch Logs 操作
            'logs:CreateLogGroup',
            'logs:CreateLogStream',
            'logs:PutLogEvents',
            // DynamoDB 操作
            'dynamodb:GetItem',
            'dynamodb:PutItem',
            'dynamodb:UpdateItem',
            'dynamodb:Query',
            'dynamodb:Scan',
          ],
          resources: ['*'],
        }),
        // IAM 操作を明示的に拒否（Permissions Boundary自体の変更を防止）
        new iam.PolicyStatement({
          effect: iam.Effect.DENY,
          actions: [
            'iam:CreatePolicy',
            'iam:DeletePolicy',
            'iam:CreatePolicyVersion',
            'iam:DeletePolicyVersion',
            'iam:SetDefaultPolicyVersion',
            'iam:AttachUserPolicy',
            'iam:AttachGroupPolicy',
            'iam:AttachRolePolicy',
            'iam:DetachUserPolicy',
            'iam:DetachGroupPolicy',
            'iam:DetachRolePolicy',
            'iam:PutUserPermissionsBoundary',
            'iam:PutRolePermissionsBoundary',
            'iam:DeleteUserPermissionsBoundary',
            'iam:DeleteRolePermissionsBoundary',
          ],
          resources: ['*'],
        }),
      ],
    });

    // IAM Deny ポリシーの作成
    this.denyPolicy = new iam.ManagedPolicy(this, 'SecurityDenyPolicy', {
      managedPolicyName: 'CDKSecurityDenyPolicy',
      description: 'セキュリティ設定の変更を拒否し、権限昇格を防止',
      statements: [
        // Permissions Boundary の削除・変更を拒否
        new iam.PolicyStatement({
          effect: iam.Effect.DENY,
          actions: [
            'iam:DeleteRolePermissionsBoundary',
            'iam:DeleteUserPermissionsBoundary',
            'iam:PutRolePermissionsBoundary',
            'iam:PutUserPermissionsBoundary',
          ],
          resources: ['*'],
          conditions: {
            StringNotEquals: {
              'aws:PrincipalArn': 'arn:aws:iam::*:role/AdminRole',
            },
          },
        }),
        // IAM ポリシーの変更を拒否
        new iam.PolicyStatement({
          effect: iam.Effect.DENY,
          actions: [
            'iam:CreatePolicy',
            'iam:DeletePolicy',
            'iam:CreatePolicyVersion',
            'iam:DeletePolicyVersion',
            'iam:SetDefaultPolicyVersion',
          ],
          resources: [
            'arn:aws:iam::*:policy/CDKPermissionsBoundary',
            'arn:aws:iam::*:policy/CDKSecurityDenyPolicy',
          ],
        }),
        // セキュリティグループの過度な開放を拒否
        new iam.PolicyStatement({
          effect: iam.Effect.DENY,
          actions: [
            'ec2:AuthorizeSecurityGroupIngress',
            'ec2:AuthorizeSecurityGroupEgress',
          ],
          resources: ['*'],
          conditions: {
            IpAddress: {
              'aws:SourceIp': ['0.0.0.0/0'],
            },
          },
        }),
      ],
    });

    // 出力
    new cdk.CfnOutput(this, 'PermissionsBoundaryArn', {
      value: this.permissionsBoundary.managedPolicyArn,
      description: 'Permissions Boundary ARN（アプリケーションから参照）',
      exportName: 'CDKPermissionsBoundaryArn',
    });

    new cdk.CfnOutput(this, 'DenyPolicyArn', {
      value: this.denyPolicy.managedPolicyArn,
      description: 'Deny Policy ARN（アプリケーションから参照）',
      exportName: 'CDKSecurityDenyPolicyArn',
    });
  }
}
