# CDK with Permissions Boundary サンプル実装

AWS CDKを使用する際のセキュリティ強化手法を実装したサンプルプロジェクトです。

## 📋 概要

CDKを安全に運用するための4つの主要なセキュリティ機能を実装しています：

1. **Qualifier** - 環境ごとの物理的分離
2. **Permissions Boundary** - 実行可能な操作の上限設定
3. **IAM Deny Policy** - セキュリティ設定の変更防止
4. **CDK Aspects** - デプロイ前のセキュリティ検証

## 🚀 クイックスタート

### 管理者: 初期セットアップ

```bash
# Permissions Boundaryのセットアップ
./scripts/admin/01-setup-permissions-boundary.sh

# Bootstrapの実行
./scripts/admin/02-bootstrap-with-qualifier.sh
```

### 開発者: アプリケーションのデプロイ

```bash
# 設定確認
./scripts/developer/01-configure-qualifier.sh

# デプロイ
./scripts/developer/02-deploy-app.sh
```

詳細な手順とスクリプトの説明は [SETUP_GUIDE.md](SETUP_GUIDE.md) を参照してください。

## 📂 プロジェクト構成

```
scripts/                    # 実行用スクリプト（詳細な説明付き）
├── admin/                  # 管理者用
│   ├── 01-setup-permissions-boundary.sh  # Permissions Boundaryセットアップ
│   └── 02-bootstrap-with-qualifier.sh    # Bootstrap実行
└── developer/              # 開発者用
    ├── 01-configure-qualifier.sh         # 設定確認
    └── 02-deploy-app.sh                  # アプリデプロイ

cdk-setup/                  # 管理者用CDKアプリ
└── lib/
    └── cdk-setup-stack.ts  # Permissions Boundary + Deny Policy

cdk-app/                    # 開発者用CDKアプリ
├── lib/
│   ├── cdk-app-stack.ts    # メインスタック
│   └── security-aspects.ts # セキュリティ検証
└── cdk.json                # Qualifier設定

.github/workflows/          # GitHub Actions（手動トリガーのみ）
├── admin-setup.yml         # 管理者セットアップ
└── developer-deploy.yml    # 開発者デプロイ
```

## 📚 ドキュメント

- **[SECURITY_FEATURES.md](SECURITY_FEATURES.md)** - アーキテクチャ図とセキュリティ機能の詳細
- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - セットアップ手順とトラブルシューティング

## 🔒 セキュリティ機能の概要

詳細は [SECURITY_FEATURES.md](SECURITY_FEATURES.md) を参照してください。

### 1. Qualifier - 環境分離
環境ごとに異なるリソースを作成し、物理的に分離します。

### 2. Permissions Boundary - 権限上限
IAMロールが実行できる操作の上限を設定します。

### 3. IAM Deny Policy - 脱獄防止
Permissions Boundaryの削除・変更を拒否します。

### 4. CDK Aspects - 自動検証
デプロイ前にセキュリティ設定を自動検証します。

## 🧪 テスト

```bash
cd cdk-app
npm test  # 13個のテストを実行
```

## 📄 ライセンス

MIT