# CDK Setup Stack

このスタックは**管理者のみ**が最初にデプロイします。

## 目的

- Permissions Boundary ポリシーを作成
- Deny Policy ポリシーを作成
- これらのポリシーをエクスポートし、アプリケーションスタックから参照可能にする

## デプロイ手順（管理者のみ）

```bash
cd cdk-setup
npm install
npm run build
cdk deploy
```

## 出力

デプロイ後、以下のARNがエクスポートされます：

- `CDKPermissionsBoundaryArn` - Permissions Boundary ARN
- `CDKSecurityDenyPolicyArn` - Deny Policy ARN

これらは `cdk-app` スタックから参照されます。

## 注意事項

⚠️ このスタックは**管理者のみ**がデプロイできます。  
⚠️ 開発者はこのスタックをデプロイできません。
