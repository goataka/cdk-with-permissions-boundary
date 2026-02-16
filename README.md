# CDK with Permissions Boundary サンプル実装

このリポジトリは、AWS CDKを使用する際のセキュリティ強化手法を実装したサンプルプロジェクトです。

## 📋 概要

CDKを安全に運用するための4つの主要なセキュリティ機能を実装しています：

1. **Qualifier** - 物理的な場所の分離
2. **Permissions Boundary** - 実行可能な操作の制限
3. **IAM Deny Policy** - 設定変更（脱獄）の防止
4. **CDK Aspects** - 設定ミスの検出と却下

## 🚀 クイックスタート

### 管理者の初期セットアップ

```bash
# 1. セキュリティポリシーの作成（管理者のみ）
cd cdk-with-permissions-boundary/cdk-setup
npm install
npm run build
cdk deploy

# 2. Bootstrapの実行（管理者のみ）
cdk bootstrap --qualifier pbdemo \
  --toolkit-stack-name CDKToolkit-pbdemo \
  aws://YOUR_ACCOUNT_ID/YOUR_REGION
```

### 開発者のアプリ開発

```bash
# 3. アプリケーションの開発とデプロイ（開発者）
cd cdk-with-permissions-boundary/cdk-app
npm install
npm run build
npm test
npx cdk deploy
```

詳細なセットアップ手順は [SETUP_GUIDE.md](cdk-app/SETUP_GUIDE.md) を参照してください。

## 📂 プロジェクト構成

```
cdk-setup/                              # 管理者が最初にデプロイ
├── bin/
│   └── cdk-setup.ts                    # セットアップエントリー
└── lib/
    └── cdk-setup-stack.ts              # Permissions Boundary + Deny Policy

cdk-app/                                # 開発者がデプロイ
├── bin/
│   └── cdk-app.ts                      # アプリエントリーポイント
├── lib/
│   ├── cdk-app-stack.ts                # メインスタック
│   ├── permissions-boundary-policy.ts  # Permissions Boundary（参照用）
│   ├── deny-policy.ts                  # IAM Deny Policy（参照用）
│   └── security-aspects.ts             # CDK Aspects
├── test/
│   └── cdk-app.test.ts                 # テスト（13個）
└── cdk.json                            # CDK設定（Qualifier: pbdemo）
```

## 📚 ドキュメント

- **[SECURITY_FEATURES.md](SECURITY_FEATURES.md)** - セキュリティ機能の詳細説明、AWS構成図、実装例
- **[SETUP_GUIDE.md](cdk-app/SETUP_GUIDE.md)** - 詳細なセットアップ手順、動作確認方法
- **[サンプルコード](cdk-app/lib/)** - 各セキュリティ機能の実装

## 🔒 セキュリティ機能

各機能の詳細は [SECURITY_FEATURES.md](SECURITY_FEATURES.md) を参照してください。

### 1. Qualifier による環境分離
カスタムQualifier `pbdemo` により、環境ごとに異なるリソースを作成し、物理的に分離します。

### 2. Permissions Boundary による権限制限
IAMロールが実行できる操作の上限を定義し、過度な権限付与を防止します。

### 3. IAM Deny Policy による脱獄防止
Permissions Boundaryの削除・変更を拒否し、権限昇格を防止します。

### 4. CDK Aspects による設定検証
デプロイ前に設定ミスを自動検出し、セキュアでない設定をブロックします。

## 🧪 テスト

```bash
npm test
```

13個のテストで以下を検証：
- Permissions Boundary適用
- IAM Deny Policy設定
- S3セキュリティ設定
- Lambda関数設定
- スタック出力

## 🤝 コントリビューション

プルリクエストを歓迎します。大きな変更の場合は、まずissueを開いて変更内容を議論してください。

## 📄 ライセンス

このプロジェクトはMITライセンスの下でライセンスされています。
  resources: ['*'],
})
```

### 3. IAM Deny による脱獄防止

**実装ファイル**: `lib/deny-policy.ts`

**主な機能**:
- Permissions Boundaryの削除・変更を拒否
- セキュリティポリシーの変更を拒否
- セキュリティグループの全開放(0.0.0.0/0)を拒否

**サンプルコード**:
```typescript
// lib/deny-policy.ts
new iam.PolicyStatement({
  effect: iam.Effect.DENY,
  actions: [
    'iam:DeleteRolePermissionsBoundary',
    'iam:PutRolePermissionsBoundary',
  ],
  resources: ['*'],
})
```

### 4. CDK Aspects による設定検証

**実装ファイル**: `lib/security-aspects.ts`

**検証項目**:

#### IAMロール検証
- ❌ AdministratorAccessポリシーの使用を禁止
- ⚠️ ワイルドカード(*)アクションの使用を警告

#### S3セキュリティ検証
- ❌ 暗号化が未設定の場合はエラー
- ⚠️ バージョニングが無効の場合は警告
- ❌ パブリックアクセスブロックが未設定の場合はエラー

**サンプルコード**:
```typescript
// bin/cdk-app.ts
import { PermissionsBoundaryAspect, IamRoleValidationAspect, S3SecurityAspect } from '../lib/security-aspects';

// すべてのIAMロールにPermissions Boundaryを適用
cdk.Aspects.of(stack).add(new PermissionsBoundaryAspect(permissionsBoundaryArn));

// IAMロールの検証
cdk.Aspects.of(stack).add(new IamRoleValidationAspect());

// S3セキュリティの検証
cdk.Aspects.of(stack).add(new S3SecurityAspect());
```

## 🧪 動作確認

### スタックの確認

```bash
# デプロイされたスタックの確認
aws cloudformation describe-stacks --stack-name CdkAppStack

# 作成されたリソースの確認
aws cloudformation list-stack-resources --stack-name CdkAppStack
```

### Lambda関数のテスト

```bash
# Lambda関数の実行
aws lambda invoke \
  --function-name sample-function-with-pb \
  --payload '{}' \
  response.json

cat response.json
```

### Permissions Boundaryの確認

```bash
# IAMロールに適用されたPermissions Boundaryの確認
aws iam get-role --role-name custom-role-with-pb
```

出力例:
```json
{
  "Role": {
    "PermissionsBoundary": {
      "PermissionsBoundaryType": "Policy",
      "PermissionsBoundaryArn": "arn:aws:iam::123456789012:policy/CDKPermissionsBoundary"
    }
  }
}
```

## 📝 カスタマイズ

### Permissions Boundaryの権限を調整

`lib/permissions-boundary-policy.ts`を編集して、許可する操作を追加・削除できます。

```typescript
actions: [
  's3:GetObject',
  's3:PutObject',
  // 新しい操作を追加
  'dynamodb:GetItem',
  'sqs:SendMessage',
],
```

### CDK Aspectsの検証ルールを追加

`lib/security-aspects.ts`に新しい検証クラスを追加できます。

```typescript
export class CustomValidationAspect implements cdk.IAspect {
  public visit(node: IConstruct): void {
    // カスタム検証ロジック
  }
}
```

## 🔧 トラブルシューティング

### Q: デプロイ時にPermissions Boundaryエラーが発生する

**A**: Permissions Boundaryポリシーが存在するか確認してください。
```bash
aws iam get-policy --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/CDKPermissionsBoundary
```

### Q: CDK Aspectsの警告が表示される

**A**: 警告を修正するか、意図的なものであれば継続できます。エラー（❌）は必ず修正が必要です。

### Q: カスタムQualifierでデプロイできない

**A**: ブートストラップが正しく実行されているか確認してください。
```bash
aws cloudformation describe-stacks --stack-name CDKToolkit-pbdemo
```

## 📚 参考資料

- [AWS CDK Permissions Boundary](https://docs.aws.amazon.com/cdk/v2/guide/permissions.html#permissions-boundary)
- [IAM Permissions Boundaries](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html)
- [CDK Aspects](https://docs.aws.amazon.com/cdk/v2/guide/aspects.html)
- [CDK Bootstrapping](https://docs.aws.amazon.com/cdk/v2/guide/bootstrapping.html)

## 🤝 コントリビューション

プルリクエストを歓迎します。大きな変更の場合は、まずissueを開いて変更内容を議論してください。

## 📄 ライセンス

このプロジェクトはMITライセンスの下でライセンスされています。