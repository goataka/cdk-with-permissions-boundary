# CDK with Permissions Boundary サンプル実装

AWS CDKを使用する際の**IAM権限の過剰付与を防止**し、**権限昇格攻撃（脱獄）からの保護**を実現するサンプルプロジェクトです。

## 🎯 プロジェクトの目的

このサンプルは、以下の課題を解決します：

- **IAM権限の過剰付与防止** - 開発者が誤って強力すぎる権限を付与することを防止
- **権限昇格攻撃からの保護** - Permissions Boundaryの削除・変更による「脱獄」を防止
- **マルチテナント環境での権限分離** - 複数の開発チーム/環境間での権限の明確な分離

## 🔒 セキュリティ機能の詳細

### 1. Qualifier - 環境分離（Bootstrap時）

**設定方法:**
```bash
cdk bootstrap --qualifier pbdemo
```

**効果:**
- 環境ごとに異なるBootstrapリソース（S3/ECR/IAMロール）を作成
- 物理的な分離により、環境間の干渉を防止

### 2. Permissions Boundary - 権限上限（cdk.json設定）

**設定方法:**
```json
{
  "context": {
    "@aws-cdk/core:permissionsBoundary": {
      "name": "CDKPermissionsBoundary"
    }
  }
}
```

**効果:**
- CDKが作成する**すべてのIAMロール**に自動的にPermissions Boundaryを適用
- ロールに付与できる権限の上限を制限（S3、Lambda等のみ許可、IAM操作は拒否）
- 開発者が誤って過剰な権限を付与しても、実際には制限内の権限のみ有効

**補助機能:**
- CDK Aspectsがcdk.json未設定時の保険として追加検証

### 3. IAM Deny Policy - 脱獄防止（明示的アタッチ）

**設定方法:**
```typescript
role.addManagedPolicy(
  iam.ManagedPolicy.fromManagedPolicyArn(
    this,
    'DenyPolicy',
    denyPolicyArn
  )
);
```

**強制する仕組み:**
- Permissions Boundaryの削除・変更を拒否
- セキュリティポリシーの変更を拒否
- セキュリティグループの全開放(0.0.0.0/0)を拒否

**注意:** Permissions Boundaryと異なり、自動適用されないため、各ロールに明示的にアタッチが必要

### 4. CDK Aspects - 補助的検証（デプロイ前チェック）

**役割:**
- CDKが自動生成するロールの追加検証
- cdk.json未設定時の保険
- AdministratorAccess権限の禁止
- S3セキュリティ設定の検証
- ワイルドカード権限の警告

## 📂 サンプル構成の説明

このリポジトリには、以下のサンプルが含まれています：

```
scripts/                    # 実行用スクリプト（詳細な日本語説明付き）
├── admin/                  # 管理者用
│   ├── 01-setup-permissions-boundary.sh  # Permissions Boundaryセットアップ
│   └── 02-bootstrap-with-qualifier.sh    # Bootstrap実行
└── developer/              # 開発者用
    ├── 01-configure-qualifier.sh         # 設定確認
    └── 02-deploy-app.sh                  # アプリデプロイ

cdk-setup/                  # 管理者用CDKアプリ（サンプル）
└── lib/
    └── cdk-setup-stack.ts  # Permissions Boundary + Deny Policy作成

cdk-app/                    # 開発者用CDKアプリ（サンプル）
├── lib/
│   ├── cdk-app-stack.ts    # Lambda + S3のサンプルスタック
│   └── security-aspects.ts # 補助的なセキュリティ検証
└── cdk.json                # Permissions Boundary設定（重要）

cloudformation/             # OIDC初期セットアップ用
└── github-oidc-setup.yml   # GitHub ActionsのOIDC認証設定

.github/workflows/          # GitHub Actions（手動トリガーのみ）
├── admin-setup.yml         # 管理者セットアップ（OIDC認証）
└── developer-deploy.yml    # 開発者デプロイ（OIDC認証）
```

各スクリプトには詳細な日本語コメントが含まれており、実行するだけで動作を理解できます。

## 🚀 セットアップ手順

### 1. 管理者: 初期セットアップ

```bash
# Permissions Boundaryのセットアップ
./scripts/admin/01-setup-permissions-boundary.sh

# Bootstrapの実行（Qualifier指定）
./scripts/admin/02-bootstrap-with-qualifier.sh
```

### 2. 開発者: アプリケーションのデプロイ

```bash
# 設定確認
./scripts/developer/01-configure-qualifier.sh

# デプロイ
./scripts/developer/02-deploy-app.sh
```

詳細な手順とトラブルシューティングは [SETUP_GUIDE.md](SETUP_GUIDE.md) を参照してください。

## 📚 ドキュメント

- **[SECURITY_FEATURES.md](SECURITY_FEATURES.md)** - アーキテクチャ図とセキュリティ機能の詳細
- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - セットアップ手順とトラブルシューティング

## 🧪 テスト

```bash
cd cdk-app
npm test  # 13個のテストを実行
```

## 📄 ライセンス

MIT