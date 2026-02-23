import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

/**
 * IAM Deny ポリシーを作成
 * 重要な設定の変更を防止し、「脱獄」を防ぐ
 */
export class DenyPolicy extends Construct {
  public readonly policy: iam.ManagedPolicy;

  constructor(scope: Construct, id: string) {
    super(scope, id);

    // セキュリティ設定の変更を拒否するポリシー
    this.policy = new iam.ManagedPolicy(this, 'SecurityDenyPolicy', {
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
              'aws:PrincipalArn': 'arn:aws:iam::*:role/AdminRole', // 管理者ロールのみ変更可能
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
              'aws:SourceIp': ['0.0.0.0/0'], // 全開放を拒否
            },
          },
        }),
      ],
    });
  }
}
