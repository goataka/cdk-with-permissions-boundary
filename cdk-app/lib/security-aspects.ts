import * as cdk from 'aws-cdk-lib/core';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as s3 from 'aws-cdk-lib/aws-s3';
import { IConstruct } from 'constructs';

/**
 * Permissions Boundary を全てのIAMロールに適用するAspect
 */
export class PermissionsBoundaryAspect implements cdk.IAspect {
  constructor(private readonly permissionsBoundaryArn: string) {}

  public visit(node: IConstruct): void {
    if (node instanceof iam.Role) {
      const cfnRole = node.node.defaultChild as iam.CfnRole;
      cfnRole.permissionsBoundary = this.permissionsBoundaryArn;
    }
  }
}

/**
 * IAMロールの設定を検証するAspect
 */
export class IamRoleValidationAspect implements cdk.IAspect {
  public visit(node: IConstruct): void {
    if (node instanceof iam.Role) {
      // AdministratorAccess ポリシーの使用を禁止
      const role = node as iam.Role;
      const cfnRole = role.node.defaultChild as iam.CfnRole;
      
      if (cfnRole.managedPolicyArns) {
        const managedPolicyArns = cdk.Token.isUnresolved(cfnRole.managedPolicyArns)
          ? []
          : (cfnRole.managedPolicyArns as string[]);
        
        managedPolicyArns.forEach((arn) => {
          if (arn.includes('AdministratorAccess')) {
            cdk.Annotations.of(node).addError(
              '❌ AdministratorAccessポリシーの使用は禁止されています。最小権限の原則に従ってください。'
            );
          }
        });
      }

      // インラインポリシーで "*" アクションの使用を警告
      if (cfnRole.policies) {
        const policies = cfnRole.policies as any[];
        policies.forEach((policy) => {
          const policyDoc = policy.policyDocument;
          if (policyDoc && policyDoc.Statement) {
            policyDoc.Statement.forEach((statement: any) => {
              if (statement.Action && statement.Action.includes('*')) {
                cdk.Annotations.of(node).addWarning(
                  '⚠️  ワイルドカード(*)アクションの使用は推奨されません。具体的なアクションを指定してください。'
                );
              }
            });
          }
        });
      }
    }
  }
}

/**
 * S3バケットのセキュリティ設定を検証するAspect
 */
export class S3SecurityAspect implements cdk.IAspect {
  public visit(node: IConstruct): void {
    if (node instanceof s3.CfnBucket) {
      const bucket = node as s3.CfnBucket;

      // バージョニングが有効でない場合は警告
      const versioningConfig = bucket.versioningConfiguration as any;
      if (!versioningConfig || 
          !versioningConfig.status || 
          versioningConfig.status !== 'Enabled') {
        cdk.Annotations.of(node).addWarning(
          '⚠️  S3バケットのバージョニングが有効になっていません。データ保護のため有効化を推奨します。'
        );
      }

      // 暗号化が有効でない場合はエラー
      if (!bucket.bucketEncryption) {
        cdk.Annotations.of(node).addError(
          '❌ S3バケットの暗号化が設定されていません。必ず暗号化を有効にしてください。'
        );
      }

      // パブリックアクセスブロックが設定されていない場合はエラー
      if (!bucket.publicAccessBlockConfiguration) {
        cdk.Annotations.of(node).addError(
          '❌ S3バケットのパブリックアクセスブロックが設定されていません。'
        );
      }
    }
  }
}
