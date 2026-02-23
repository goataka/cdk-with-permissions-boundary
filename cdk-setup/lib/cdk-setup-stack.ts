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

    // Permissions Boundary作成
    this.permissionsBoundary = this.createPermissionsBoundary();
    
    // Deny Policy作成
    this.denyPolicy = this.createDenyPolicy();
    
    // 出力作成
    this.createOutputs();
  }

  /**
   * Permissions Boundaryポリシーを作成
   * 
   * IAMロールの権限上限を設定し、許可する操作のみを明示的に定義します。
   */
  private createPermissionsBoundary(): iam.ManagedPolicy {
    const allowStatement = this.createAllowStatement();
    const denyStatement = this.createIamDenyStatement();

    return new iam.ManagedPolicy(this, 'PermissionsBoundary', {
      managedPolicyName: 'CDKPermissionsBoundary',
      description: 'CDKで作成されるIAMロールに適用される権限境界',
      statements: [allowStatement, denyStatement],
    });
  }

  /**
   * 許可する操作のステートメントを作成
   * 
   * S3、Lambda、CloudWatch Logs、DynamoDBの基本操作を許可します。
   */
  private createAllowStatement(): iam.PolicyStatement {
    return new iam.PolicyStatement({
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
    });
  }

  /**
   * IAM操作拒否のステートメントを作成
   * 
   * Permissions Boundary自体の変更を防止します。
   */
  private createIamDenyStatement(): iam.PolicyStatement {
    return new iam.PolicyStatement({
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
    });
  }

  /**
   * Deny Policyを作成
   * 
   * セキュリティ設定の変更を拒否し、権限昇格を防止します。
   */
  private createDenyPolicy(): iam.ManagedPolicy {
    const boundaryDenyStatement = this.createBoundaryProtectionStatement();
    const policyProtectionStatement = this.createPolicyProtectionStatement();
    const securityGroupDenyStatement = this.createSecurityGroupProtectionStatement();

    return new iam.ManagedPolicy(this, 'SecurityDenyPolicy', {
      managedPolicyName: 'CDKSecurityDenyPolicy',
      description: 'セキュリティ設定の変更を拒否し、権限昇格を防止',
      statements: [
        boundaryDenyStatement,
        policyProtectionStatement,
        securityGroupDenyStatement,
      ],
    });
  }

  /**
   * Permissions Boundary保護のステートメントを作成
   * 
   * 管理者以外によるBoundaryの削除・変更を拒否します。
   */
  private createBoundaryProtectionStatement(): iam.PolicyStatement {
    return new iam.PolicyStatement({
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
    });
  }

  /**
   * ポリシー保護のステートメントを作成
   * 
   * セキュリティポリシー自体の変更を拒否します。
   */
  private createPolicyProtectionStatement(): iam.PolicyStatement {
    return new iam.PolicyStatement({
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
    });
  }

  /**
   * セキュリティグループ保護のステートメントを作成
   * 
   * 0.0.0.0/0への過度な開放を拒否します。
   */
  private createSecurityGroupProtectionStatement(): iam.PolicyStatement {
    return new iam.PolicyStatement({
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
    });
  }

  /**
   * CloudFormation出力を作成
   * 
   * 作成したポリシーのARNを出力します。
   */
  private createOutputs(): void {
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
