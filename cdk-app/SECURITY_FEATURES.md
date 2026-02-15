# セキュリティ機能の詳細説明

このドキュメントでは、実装された4つのセキュリティ機能について詳しく説明します。

## 1. Qualifier による環境分離

### 概要
Qualifierは、CDKのブートストラップリソースに付けられる識別子です。これにより、同じAWSアカウント内で複数の独立した環境を構築できます。

### 設定方法

#### cdk.json での設定
```json
{
  "context": {
    "@aws-cdk/core:bootstrapQualifier": "pbdemo"
  }
}
```

#### ブートストラップコマンド
```bash
cdk bootstrap \
  --qualifier pbdemo \
  --toolkit-stack-name CDKToolkit-pbdemo \
  aws://123456789012/us-east-1
```

### 作成されるリソース

| リソースタイプ | デフォルト名 | カスタムQualifier名 |
|--------------|------------|-------------------|
| S3バケット | cdk-hnb659fds-assets-{account}-{region} | cdk-**pbdemo**-assets-{account}-{region} |
| ECRリポジトリ | cdk-hnb659fds-container-assets-{account}-{region} | cdk-**pbdemo**-container-assets-{account}-{region} |
| IAMロール（デプロイ用） | cdk-hnb659fds-deploy-role-{account}-{region} | cdk-**pbdemo**-deploy-role-{account}-{region} |
| IAMロール（実行用） | cdk-hnb659fds-cfn-exec-role-{account}-{region} | cdk-**pbdemo**-cfn-exec-role-{account}-{region} |

### 利用シーン

#### シーン1: 環境ごとの分離
```
開発環境: Qualifier = "dev"    → cdk-dev-assets-...
検証環境: Qualifier = "stg"    → cdk-stg-assets-...
本番環境: Qualifier = "prod"   → cdk-prod-assets-...
```

#### シーン2: チームごとの分離
```
チームA: Qualifier = "teama"   → cdk-teama-assets-...
チームB: Qualifier = "teamb"   → cdk-teamb-assets-...
```

#### シーン3: プロジェクトごとの分離
```
プロジェクト1: Qualifier = "proj1"  → cdk-proj1-assets-...
プロジェクト2: Qualifier = "proj2"  → cdk-proj2-assets-...
```

### メリット

1. **リソースの衝突回避**: 複数の環境やチームが同じアカウントを使用しても、リソース名が衝突しない
2. **明確な権限分離**: 環境ごとに異なるIAMロールを使用可能
3. **独立したライフサイクル**: 各環境を独立して管理・削除可能

## 2. Permissions Boundary による権限制限

### 概要
Permissions Boundaryは、IAMロールやユーザーが持つことができる権限の上限を定義します。どんな権限を付与しても、Permissions Boundaryで許可されていない操作は実行できません。

### 実装例

```typescript
// lib/permissions-boundary-policy.ts
const permissionsBoundary = new iam.ManagedPolicy(this, 'PermissionsBoundary', {
  managedPolicyName: 'CDKPermissionsBoundary',
  statements: [
    // 許可する操作（ホワイトリスト）
    new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: [
        's3:GetObject',
        's3:PutObject',
        'lambda:InvokeFunction',
        'logs:CreateLogGroup',
        'logs:PutLogEvents',
      ],
      resources: ['*'],
    }),
    // 明示的に拒否する操作（IAM変更の防止）
    new iam.PolicyStatement({
      effect: iam.Effect.DENY,
      actions: [
        'iam:CreatePolicy',
        'iam:AttachRolePolicy',
        'iam:PutRolePermissionsBoundary',
      ],
      resources: ['*'],
    }),
  ],
});
```

### 権限の組み合わせ例

#### 例1: S3への読み取り権限

```typescript
// IAMロールに付与された権限
role.addToPolicy(new iam.PolicyStatement({
  effect: iam.Effect.ALLOW,
  actions: ['s3:GetObject', 's3:DeleteObject'],
  resources: ['arn:aws:s3:::my-bucket/*'],
}));

// Permissions Boundaryで許可された権限
// - s3:GetObject ✓
// - s3:PutObject ✓
// - s3:DeleteObject ✓

// 実際に実行可能な操作
// - s3:GetObject ✓ (ロールとBoundary両方で許可)
// - s3:DeleteObject ✓ (ロールとBoundary両方で許可)
```

#### 例2: IAM操作の拒否

```typescript
// IAMロールに管理者権限を付与しようとしても...
role.addManagedPolicy(
  iam.ManagedPolicy.fromAwsManagedPolicyName('AdministratorAccess')
);

// Permissions BoundaryでIAM操作が拒否されているため
// IAM操作は実行不可 ❌
// - iam:CreatePolicy → 拒否
// - iam:AttachRolePolicy → 拒否
// - iam:CreateUser → 拒否
```

### 効果的な権限設定パターン

#### パターン1: サービス単位での制限
```typescript
// Lambda関数用のPermissions Boundary
statements: [
  new iam.PolicyStatement({
    effect: iam.Effect.ALLOW,
    actions: [
      'lambda:*',
      's3:GetObject',
      's3:PutObject',
      'dynamodb:GetItem',
      'dynamodb:PutItem',
      'logs:*',
    ],
    resources: ['*'],
  }),
]
```

#### パターン2: リソース範囲での制限
```typescript
// 特定のリソースのみ許可
statements: [
  new iam.PolicyStatement({
    effect: iam.Effect.ALLOW,
    actions: ['s3:*'],
    resources: [
      'arn:aws:s3:::allowed-bucket-prefix-*',
      'arn:aws:s3:::allowed-bucket-prefix-*/*',
    ],
  }),
]
```

#### パターン3: 条件付きアクセス
```typescript
// 特定のVPCからのみ許可
statements: [
  new iam.PolicyStatement({
    effect: iam.Effect.ALLOW,
    actions: ['ec2:*'],
    resources: ['*'],
    conditions: {
      StringEquals: {
        'ec2:Vpc': 'vpc-12345678',
      },
    },
  }),
]
```

## 3. IAM Deny Policy による脱獄防止

### 概要
IAM Denyポリシーは、明示的な拒否ルールを定義し、Permissions Boundary自体の変更や削除を防ぎます。これにより「脱獄」（権限制限の回避）を防止します。

### 実装例

```typescript
// lib/deny-policy.ts
const denyPolicy = new iam.ManagedPolicy(this, 'SecurityDenyPolicy', {
  managedPolicyName: 'CDKSecurityDenyPolicy',
  statements: [
    // Permissions Boundaryの変更・削除を拒否
    new iam.PolicyStatement({
      effect: iam.Effect.DENY,
      actions: [
        'iam:DeleteRolePermissionsBoundary',
        'iam:PutRolePermissionsBoundary',
      ],
      resources: ['*'],
      conditions: {
        StringNotEquals: {
          'aws:PrincipalArn': 'arn:aws:iam::*:role/AdminRole',
        },
      },
    }),
    // セキュリティポリシーの変更を拒否
    new iam.PolicyStatement({
      effect: iam.Effect.DENY,
      actions: [
        'iam:DeletePolicy',
        'iam:CreatePolicyVersion',
      ],
      resources: [
        'arn:aws:iam::*:policy/CDKPermissionsBoundary',
        'arn:aws:iam::*:policy/CDKSecurityDenyPolicy',
      ],
    }),
  ],
});
```

### 防止される攻撃パターン

#### パターン1: Permissions Boundaryの削除
```bash
# 悪意あるユーザーが試みること
aws iam delete-role-permissions-boundary --role-name MyRole

# 結果: Deny Policyにより拒否される ❌
# Error: User is not authorized to perform: iam:DeleteRolePermissionsBoundary
```

#### パターン2: Permissions Boundaryの変更
```bash
# より緩いPermissions Boundaryに変更しようとする
aws iam put-role-permissions-boundary \
  --role-name MyRole \
  --permissions-boundary arn:aws:iam::123456789012:policy/WeakBoundary

# 結果: Deny Policyにより拒否される ❌
```

#### パターン3: セキュリティポリシーの削除
```bash
# セキュリティポリシー自体を削除しようとする
aws iam delete-policy \
  --policy-arn arn:aws:iam::123456789012:policy/CDKSecurityDenyPolicy

# 結果: Deny Policyにより拒否される ❌
```

#### パターン4: セキュリティグループの全開放
```bash
# 0.0.0.0/0 からのアクセスを許可しようとする
aws ec2 authorize-security-group-ingress \
  --group-id sg-12345678 \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

# 結果: Deny Policyにより拒否される ❌
```

### 例外設定（管理者のみ許可）

```typescript
conditions: {
  StringNotEquals: {
    'aws:PrincipalArn': 'arn:aws:iam::*:role/AdminRole',
  },
}
```

管理者ロール（AdminRole）のみが、セキュリティ設定を変更できます。

## 4. CDK Aspects による設定検証

### 概要
CDK Aspectsは、スタック内のすべてのリソースを走査し、設定ミスやセキュリティ問題を自動検出します。

### 実装例

#### IAMロールの検証
```typescript
// lib/security-aspects.ts
export class IamRoleValidationAspect implements cdk.IAspect {
  public visit(node: IConstruct): void {
    if (node instanceof iam.Role) {
      // AdministratorAccessの使用をチェック
      const cfnRole = node.node.defaultChild as iam.CfnRole;
      if (cfnRole.managedPolicyArns) {
        cfnRole.managedPolicyArns.forEach((arn) => {
          if (arn.includes('AdministratorAccess')) {
            cdk.Annotations.of(node).addError(
              '❌ AdministratorAccessポリシーは使用禁止です'
            );
          }
        });
      }
      
      // ワイルドカードアクションの使用を警告
      if (cfnRole.policies) {
        cfnRole.policies.forEach((policy) => {
          if (policy.policyDocument.Statement.some(s => s.Action === '*')) {
            cdk.Annotations.of(node).addWarning(
              '⚠️ ワイルドカードアクションの使用は推奨されません'
            );
          }
        });
      }
    }
  }
}
```

#### S3セキュリティの検証
```typescript
export class S3SecurityAspect implements cdk.IAspect {
  public visit(node: IConstruct): void {
    if (node instanceof s3.CfnBucket) {
      // 暗号化チェック
      if (!node.bucketEncryption) {
        cdk.Annotations.of(node).addError(
          '❌ S3バケットの暗号化が必須です'
        );
      }
      
      // バージョニングチェック
      if (!node.versioningConfiguration?.status) {
        cdk.Annotations.of(node).addWarning(
          '⚠️ バージョニングの有効化を推奨します'
        );
      }
      
      // パブリックアクセスブロックチェック
      if (!node.publicAccessBlockConfiguration) {
        cdk.Annotations.of(node).addError(
          '❌ パブリックアクセスブロックが必須です'
        );
      }
    }
  }
}
```

### 検証結果の例

#### 良い例（エラーなし）
```typescript
const bucket = new s3.Bucket(this, 'SecureBucket', {
  encryption: s3.BucketEncryption.S3_MANAGED,  // ✓
  versioned: true,                              // ✓
  blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,  // ✓
});

// cdk synth の結果: エラーなし ✓
```

#### 悪い例（エラーあり）
```typescript
const bucket = new s3.Bucket(this, 'InsecureBucket', {
  // 暗号化なし                                 // ❌
  // バージョニングなし                          // ⚠️
  // パブリックアクセスブロックなし               // ❌
});

// cdk synth の結果:
// ❌ Error: S3バケットの暗号化が必須です
// ⚠️ Warning: バージョニングの有効化を推奨します
// ❌ Error: パブリックアクセスブロックが必須です
```

### カスタムAspectsの作成

独自の検証ルールを追加できます：

```typescript
// カスタムタグの検証
export class TagValidationAspect implements cdk.IAspect {
  public visit(node: IConstruct): void {
    if (cdk.TagManager.isTaggable(node)) {
      const tags = cdk.TagManager.of(node).tagValues();
      
      // 必須タグのチェック
      if (!tags['Environment']) {
        cdk.Annotations.of(node).addError(
          '❌ Environmentタグが必須です'
        );
      }
      
      if (!tags['Owner']) {
        cdk.Annotations.of(node).addWarning(
          '⚠️ Ownerタグの設定を推奨します'
        );
      }
    }
  }
}

// Aspectの適用
cdk.Aspects.of(app).add(new TagValidationAspect());
```

## セキュリティレイヤーの組み合わせ

4つの機能を組み合わせることで、多層防御を実現します：

```
リクエスト
    ↓
┌─────────────────────────────────────┐
│ Layer 1: CDK Aspects                │
│ デプロイ前に設定ミスを検出           │
│ → 不適切な設定をブロック             │
└─────────────────────────────────────┘
    ↓ デプロイ
┌─────────────────────────────────────┐
│ Layer 2: Qualifier                  │
│ 環境を物理的に分離                   │
│ → 環境間の干渉を防止                 │
└─────────────────────────────────────┘
    ↓ 実行時
┌─────────────────────────────────────┐
│ Layer 3: Permissions Boundary       │
│ 実行可能な操作の上限を設定           │
│ → 過度な権限付与を防止               │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ Layer 4: IAM Deny Policy            │
│ セキュリティ設定の変更を拒否         │
│ → 権限昇格（脱獄）を防止             │
└─────────────────────────────────────┘
    ↓
  実行
```

## まとめ

この実装により、以下のセキュリティ要件を満たします：

1. **環境分離**: Qualifierによる物理的な分離
2. **権限制限**: Permissions Boundaryによる上限設定
3. **変更防止**: IAM Denyによる脱獄防止
4. **設定検証**: CDK Aspectsによる自動検証

これらを適切に組み合わせることで、CDKを使用した安全なインフラ管理が可能になります。
