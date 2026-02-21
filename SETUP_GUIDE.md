# セットアップガイド

このガイドでは、CDK with Permissions Boundaryプロジェクトのセットアップから動作確認までを説明します。

## 事前準備

### 必要なツール

- **AWS CLI** (認証情報設定済み)
- **Node.js** 18.x以上
- **AWS CDK CLI** (`npm install -g aws-cdk`)

インストール方法の詳細は、各ツールの公式ドキュメントを参照してください。

## セットアップ手順

### ステップ1: リポジトリのクローン

```bash
git clone https://github.com/goataka/cdk-with-permissions-boundary.git
cd cdk-with-permissions-boundary
```

### ステップ2: 管理者による初期セットアップ

#### 2-1. Permissions Boundaryのセットアップ

```bash
./scripts/admin/01-setup-permissions-boundary.sh
```

このスクリプトは以下を実行します：
- CDK Setup Stackのビルドとデプロイ
- Permissions BoundaryとDeny Policyの作成
- 作成されたポリシーARNの表示

**詳細な実行内容とコメント**は、[スクリプトファイル](scripts/admin/01-setup-permissions-boundary.sh)内を参照してください。

#### 2-2. Bootstrapの実行

```bash
./scripts/admin/02-bootstrap-with-qualifier.sh
```

このスクリプトは以下を実行します：
- カスタムQualifier `pbdemo` でのBootstrap
- Permissions Boundaryの自動適用
- S3バケット、ECRリポジトリ、IAMロールの作成
- セキュリティ設定の検証

**詳細な実行内容とコメント**は、[スクリプトファイル](scripts/admin/02-bootstrap-with-qualifier.sh)内を参照してください。

### ステップ3: 開発者によるアプリケーションデプロイ

#### 3-1. Qualifier設定の確認

```bash
./scripts/developer/01-configure-qualifier.sh
```

このスクリプトは以下を確認します：
- cdk.jsonのQualifier設定
- Permissions Boundary設定
- Bootstrapスタックの存在と状態

詳細は[スクリプトファイル](scripts/developer/01-configure-qualifier.sh)を参照してください。

#### 3-2. アプリケーションのデプロイ

```bash
./scripts/developer/02-deploy-app.sh
```

このスクリプトは以下を実行します：
- 依存関係のインストールとビルド
- テストの実行
- CDK Aspectsによるセキュリティ検証
- CloudFormationテンプレートの生成
- アプリケーションのデプロイ
- セキュリティ設定の検証

**詳細な実行内容とコメント**は、[スクリプトファイル](scripts/developer/02-deploy-app.sh)内を参照してください。

## GitHub Actionsの使用

### 管理者セットアップ（手動トリガー）

GitHub Actionsタブから `管理者セットアップ` ワークフローを実行：

1. Actionsタブを開く
2. "管理者セットアップ" を選択
3. "Run workflow" をクリック
4. Qualifierを指定（デフォルト: `pbdemo`）
5. 実行

詳細は [.github/workflows/admin-setup.yml](.github/workflows/admin-setup.yml) を参照してください。

### 開発者デプロイ（手動トリガー）

GitHub Actionsタブから `開発者デプロイ` ワークフローを実行：

1. Actionsタブを開く
2. "開発者デプロイ" を選択
3. "Run workflow" をクリック
4. スタック名を指定（デフォルト: `CdkAppStack`）
5. 実行

詳細は [.github/workflows/developer-deploy.yml](.github/workflows/developer-deploy.yml) を参照してください。

## 動作確認

デプロイ後の動作確認方法については、各スクリプトの実行結果に表示されます。
基本的な確認コマンド例：

```bash
# Lambda関数の実行
aws lambda invoke \
  --function-name <FUNCTION_NAME> \
  --payload '{}' \
  response.json

# S3バケットへのアップロード
echo 'test' > test.txt
aws s3 cp test.txt s3://<BUCKET_NAME>/test.txt

# Permissions Boundaryの確認
aws iam get-role --role-name <ROLE_NAME>
```

## トラブルシューティング

### エラー: "Policy ... does not exist"

**原因**: Permissions Boundaryがまだ作成されていない

**解決方法**: 
```bash
./scripts/admin/01-setup-permissions-boundary.sh
```
を実行してください。

### エラー: "Unable to resolve AWS account"

**原因**: AWS認証情報が正しく設定されていない

**解決方法**:
```bash
aws configure
# または
export AWS_PROFILE=your-profile-name
```

### エラー: "This CDK deployment requires bootstrap stack version ..."

**原因**: Bootstrapが未実行または古い

**解決方法**:
```bash
./scripts/admin/02-bootstrap-with-qualifier.sh
```

### CDK Aspectsの警告やエラー

**警告**: 修正推奨だが、デプロイは継続可能  
**エラー**: 必ず修正が必要

詳細は `cdk-app/lib/security-aspects.ts` のコメントを参照してください。

## セキュリティのベストプラクティス

各スクリプトには、以下のセキュリティ機能が組み込まれています：

1. **実行前の確認プロンプト** - 誤操作を防止
2. **Permissions Boundary自動検証** - デプロイ後に適用状態を確認
3. **S3セキュリティ検証** - 暗号化・パブリックアクセスブロックを確認
4. **詳細なログ出力** - 各ステップの実行状況を表示

詳細なセキュリティ機能については、[SECURITY_FEATURES.md](SECURITY_FEATURES.md) を参照してください。

## 次のステップ

- **カスタマイズ**: 各スクリプトのコメントを参照
- **本番環境**: Qualifierを変更して別環境としてセットアップ
- **CI/CD統合**: GitHub Actionsワークフローを参考に実装

## サポート

問題が発生した場合：

1. スクリプト内のコメントを確認
2. 各ドキュメント（README.md, SECURITY_FEATURES.md）を確認
3. GitHubのIssuesで質問
