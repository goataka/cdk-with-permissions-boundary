import * as cdk from 'aws-cdk-lib/core';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';
import { PermissionsBoundaryPolicy } from './permissions-boundary-policy';
import { DenyPolicy } from './deny-policy';
import { 
  PermissionsBoundaryAspect, 
  IamRoleValidationAspect, 
  S3SecurityAspect 
} from './security-aspects';

/**
 * CDK with Permissions Boundary のサンプルスタック
 * 
 * このスタックは以下のセキュリティ機能を実装します：
 * 1. Permissions Boundary - IAMロールの権限上限を設定
 * 2. IAM Deny Policy - 重要な設定の変更を防止
 * 3. CDK Aspects - 設定ミスを検出・防止
 * 4. Qualifier - 環境分離（cdk.jsonで設定）
 */
export class CdkAppStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // 1. Permissions Boundary ポリシーの作成
    const permissionsBoundary = new PermissionsBoundaryPolicy(this, 'PermissionsBoundary');
    
    // 2. IAM Deny ポリシーの作成
    const denyPolicy = new DenyPolicy(this, 'DenyPolicy');

    // 3. S3バケットの作成（セキュアな設定）
    const bucket = new s3.Bucket(this, 'SecureBucket', {
      bucketName: `secure-bucket-${this.account}-${this.region}`,
      // 暗号化を有効化
      encryption: s3.BucketEncryption.S3_MANAGED,
      // バージョニングを有効化
      versioned: true,
      // パブリックアクセスをブロック
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      // 削除時にバケットを空にする（開発環境用）
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
    });

    // 4. Lambda関数の作成（Permissions Boundaryが適用される）
    const lambdaFunction = new lambda.Function(this, 'SampleFunction', {
      functionName: 'sample-function-with-pb',
      runtime: lambda.Runtime.NODEJS_20_X,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        exports.handler = async (event) => {
          console.log('Lambda function with Permissions Boundary');
          return {
            statusCode: 200,
            body: JSON.stringify({ message: 'Hello from Lambda!' })
          };
        };
      `),
      // Lambda実行ロールにPermissions Boundaryが自動適用される
    });

    // Lambda関数にS3バケットへの読み取り権限を付与
    bucket.grantRead(lambdaFunction);

    // 5. カスタムIAMロールの作成（Permissions Boundaryのデモ用）
    const customRole = new iam.Role(this, 'CustomRole', {
      roleName: 'custom-role-with-pb',
      assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
      description: 'Permissions Boundaryが適用されたカスタムロール',
    });

    // カスタムロールにポリシーを追加
    customRole.addToPolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: ['s3:GetObject', 's3:ListBucket'],
        resources: [bucket.bucketArn, `${bucket.bucketArn}/*`],
      })
    );

    // 6. Deny Policyをカスタムロールにアタッチ
    customRole.addManagedPolicy(denyPolicy.policy);

    // 出力
    new cdk.CfnOutput(this, 'BucketName', {
      value: bucket.bucketName,
      description: 'セキュアなS3バケット名',
    });

    new cdk.CfnOutput(this, 'FunctionName', {
      value: lambdaFunction.functionName,
      description: 'Lambda関数名',
    });

    new cdk.CfnOutput(this, 'PermissionsBoundaryArn', {
      value: permissionsBoundary.policy.managedPolicyArn,
      description: 'Permissions Boundary ARN',
    });
  }
}
