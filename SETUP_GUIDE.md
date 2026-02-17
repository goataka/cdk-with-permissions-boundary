# セットアップガイド

このガイドでは、CDK with Permissions Boundaryプロジェクトのセットアップから動作確認までを説明します。

## 事前準備

### 必要なツール

1. **AWS CLI のインストールと設定**
   ```bash
   # AWS CLIのインストール（まだの場合）
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   
   # AWS認証情報の設定
   aws configure
   ```

2. **Node.js のインストール**
   ```bash
   # Node.js 18.x 以上をインストール
   # Ubuntuの場合
   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
   sudo apt-get install -y nodejs
   
   # macOSの場合（Homebrewを使用）
   brew install node@20
   ```

3. **AWS CDK CLI のインストール**
   ```bash
   npm install -g aws-cdk
   
   # バージョン確認
   cdk --version
   ```

## ステップ1: プロジェクトのセットアップ

```bash
# リポジトリのクローン
git clone https://github.com/goataka/cdk-with-permissions-boundary.git
cd cdk-with-permissions-boundary/cdk-app

# 依存関係のインストール
npm install
```

## ステップ2: カスタムQualifierでのブートストラップ

ブートストラップは、CDKが使用するAWSリソース（S3バケット、ECRリポジトリなど）を作成します。

```bash
# AWSアカウントIDとリージョンを取得
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=$(aws configure get region)

echo "Account ID: $AWS_ACCOUNT_ID"
echo "Region: $AWS_REGION"

# カスタムQualifier "pbdemo" でブートストラップ
cdk bootstrap \
  --qualifier pbdemo \
  --toolkit-stack-name CDKToolkit-pbdemo \
  aws://${AWS_ACCOUNT_ID}/${AWS_REGION}
```

### ブートストラップで作成されるリソース

- **S3バケット**: `cdk-pbdemo-assets-{account}-{region}` - CDKアセットの保存
- **ECRリポジトリ**: `cdk-pbdemo-container-assets-{account}-{region}` - コンテナイメージの保存
- **IAMロール**: CDKデプロイメント用のロール
- **SSMパラメータ**: ブートストラップバージョン情報

### 複数環境の分離（オプション）

本番環境用に別のQualifierを使用する場合：

```bash
# 本番環境用（Qualifier: pbprod）
cdk bootstrap \
  --qualifier pbprod \
  --toolkit-stack-name CDKToolkit-pbprod \
  aws://${PROD_ACCOUNT_ID}/${PROD_REGION}
```

## ステップ3: プロジェクトのビルド

```bash
# TypeScriptのコンパイル
npm run build
```

## ステップ4: CloudFormationテンプレートの生成

```bash
# CloudFormationテンプレートを生成して確認
npx cdk synth

# 生成されたテンプレートはcdk.out/に保存されます
ls -la cdk.out/
```

### Aspectsによる検証結果の確認

`cdk synth` の実行時に、CDK Aspectsが設定を検証します：

- ✅ セキュアな設定の場合は警告なし
- ⚠️ 推奨されない設定の場合は警告
- ❌ 禁止された設定の場合はエラー

## ステップ5: デプロイ

```bash
# スタックをAWSにデプロイ
npx cdk deploy

# 確認プロンプトで 'y' を入力
```

デプロイが完了すると、以下の出力が表示されます：

```
Outputs:
CdkAppStack.BucketName = secure-bucket-123456789012-us-east-1
CdkAppStack.FunctionName = sample-function-with-pb
CdkAppStack.PermissionsBoundaryArn = arn:aws:iam::123456789012:policy/CDKPermissionsBoundary
```

## ステップ6: 動作確認

### 6.1 デプロイされたリソースの確認

```bash
# CloudFormationスタックの確認
aws cloudformation describe-stacks \
  --stack-name CdkAppStack \
  --query 'Stacks[0].Outputs' \
  --output table

# リソース一覧
aws cloudformation list-stack-resources \
  --stack-name CdkAppStack \
  --output table
```

### 6.2 S3バケットの確認

```bash
# S3バケットの詳細確認
BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name CdkAppStack \
  --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' \
  --output text)

echo "Bucket Name: $BUCKET_NAME"

# バケット暗号化設定の確認
aws s3api get-bucket-encryption --bucket $BUCKET_NAME

# バージョニング設定の確認
aws s3api get-bucket-versioning --bucket $BUCKET_NAME

# パブリックアクセスブロック設定の確認
aws s3api get-public-access-block --bucket $BUCKET_NAME
```

### 6.3 Lambda関数のテスト

```bash
# Lambda関数の実行
aws lambda invoke \
  --function-name sample-function-with-pb \
  --payload '{"test": "data"}' \
  response.json

# レスポンスの確認
cat response.json
```

### 6.4 IAMロールとPermissions Boundaryの確認

```bash
# カスタムロールの詳細確認
aws iam get-role --role-name custom-role-with-pb

# Permissions Boundaryが適用されていることを確認
aws iam get-role \
  --role-name custom-role-with-pb \
  --query 'Role.PermissionsBoundary' \
  --output json
```

期待される出力:
```json
{
    "PermissionsBoundaryType": "Policy",
    "PermissionsBoundaryArn": "arn:aws:iam::123456789012:policy/CDKPermissionsBoundary"
}
```

### 6.5 Permissions Boundaryポリシーの内容確認

```bash
# Permissions Boundaryポリシーの詳細取得
POLICY_ARN=$(aws cloudformation describe-stacks \
  --stack-name CdkAppStack \
  --query 'Stacks[0].Outputs[?OutputKey==`PermissionsBoundaryArn`].OutputValue' \
  --output text)

echo "Policy ARN: $POLICY_ARN"

# ポリシーバージョンの取得
VERSION=$(aws iam get-policy \
  --policy-arn $POLICY_ARN \
  --query 'Policy.DefaultVersionId' \
  --output text)

# ポリシー内容の確認
aws iam get-policy-version \
  --policy-arn $POLICY_ARN \
  --version-id $VERSION \
  --query 'PolicyVersion.Document' \
  --output json
```

## ステップ7: セキュリティ機能の検証

### 7.1 Permissions Boundaryの制限を確認

カスタムロールでIAMポリシーの作成を試みます（失敗するはず）：

```bash
# カスタムロールの認証情報を使用してIAMポリシー作成を試みる
# 注: 実際の環境ではこのロールにAssumeRoleして実行
aws iam create-policy \
  --policy-name TestPolicy \
  --policy-document '{"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": "s3:*", "Resource": "*"}]}'

# Permissions Boundaryにより拒否されることを確認
```

### 7.2 S3へのアクセステスト

```bash
# Lambda関数からS3へのアクセステスト
# テストファイルをS3にアップロード
echo "Test content" > test.txt
aws s3 cp test.txt s3://$BUCKET_NAME/test.txt

# Lambda関数がS3から読み取れることを確認
aws lambda invoke \
  --function-name sample-function-with-pb \
  --payload '{"bucket": "'$BUCKET_NAME'", "key": "test.txt"}' \
  response.json
```

## ステップ8: クリーンアップ

不要になった場合は、リソースを削除します：

```bash
# スタックの削除
npx cdk destroy

# 確認プロンプトで 'y' を入力

# ブートストラップスタックの削除（必要に応じて）
aws cloudformation delete-stack --stack-name CDKToolkit-pbdemo

# S3バケットの削除（手動で残っている場合）
aws s3 rb s3://cdk-pbdemo-assets-${AWS_ACCOUNT_ID}-${AWS_REGION} --force
```

## トラブルシューティング

### エラー: "Policy ... does not exist"

**原因**: Permissions Boundaryポリシーがまだ作成されていない

**解決方法**: 
1. まず `cdk deploy` を実行してポリシーを作成
2. ポリシーARNを環境変数に設定
3. 再度デプロイ

### エラー: "Unable to resolve AWS account to use"

**原因**: AWS認証情報が正しく設定されていない

**解決方法**:
```bash
aws configure
# または
export AWS_PROFILE=your-profile-name
```

### エラー: "This CDK deployment requires bootstrap stack version ..."

**原因**: ブートストラップバージョンが古い

**解決方法**:
```bash
cdk bootstrap --force
```

### 警告: CDK Aspectsによる警告

**警告が表示される場合**: コードを修正するか、意図的な設定であればそのまま続行可能

**エラーが表示される場合**: 必ず修正が必要（デプロイがブロックされる可能性あり）

## 参考コマンド集

```bash
# CDKアプリの全スタックをリスト
npx cdk list

# 特定のスタックの差分確認
npx cdk diff CdkAppStack

# CloudFormationテンプレートの確認
npx cdk synth --no-staging

# デバッグモードでの実行
npx cdk deploy --verbose

# ロールバック設定でのデプロイ
npx cdk deploy --rollback true
```

## 次のステップ

1. **カスタマイズ**: `lib/permissions-boundary-policy.ts` を編集して、許可する操作を調整
2. **追加のAspects**: `lib/security-aspects.ts` に新しい検証ルールを追加
3. **複数環境**: 本番環境用の別のQualifierとスタックを作成
4. **CI/CD統合**: GitHub ActionsやCodePipelineでの自動デプロイを設定

## サポート

問題が発生した場合は、以下を確認してください：

1. AWS CLIの認証情報が正しく設定されているか
2. 必要なIAM権限があるか
3. ブートストラップが正しく完了しているか
4. Node.jsとAWS CDKのバージョンが要件を満たしているか

詳細は [README.md](../README.md) を参照してください。
