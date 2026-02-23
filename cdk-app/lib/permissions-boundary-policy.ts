import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

/**
 * Permissions Boundary ポリシーを作成
 * このポリシーは、IAMロールが実行できる操作の上限を定義します
 */
export class PermissionsBoundaryPolicy extends Construct {
  public readonly policy: iam.ManagedPolicy;

  constructor(scope: Construct, id: string) {
    super(scope, id);

    // Permissions Boundary ポリシーの定義
    this.policy = new iam.ManagedPolicy(this, 'PermissionsBoundary', {
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
  }
}
