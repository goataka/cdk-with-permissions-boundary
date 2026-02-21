#!/bin/bash
#
# 管理者用スクリプト: Permissions BoundaryとDeny Policyのセットアップ
#
# このスクリプトは、CDKアプリケーションで使用するPermissions BoundaryとDeny Policyを
# AWS環境にデプロイします。これらのポリシーは、開発者が作成するリソースに対して
# セキュリティ制約を適用するために使用されます。
#
# 実行前提条件:
# - AWS CLIがインストールされ、認証情報が設定されていること
# - AWS CDK CLIがインストールされていること（npm install -g aws-cdk）
# - Node.js 18.x以上がインストールされていること
# - 管理者権限を持つIAMロールまたはユーザーでログインしていること
#
# セキュリティ上の注意点:
# - このスクリプトは管理者のみが実行すべきです
# - Permissions Boundaryポリシーは、開発者が作成できるリソースの上限を定義します
# - Deny Policyは、Permissions Boundaryの削除や変更を防止します
#
set -euo pipefail

# メイン処理
main() {
  local -r script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local -r project_root="$(cd "${script_dir}/../.." && pwd)"
  local -r cdk_setup_dir="${project_root}/cdk-setup"
  
  echo "=========================================="
  echo "Permissions Boundary セットアップ"
  echo "=========================================="
  echo ""
  
  # 環境情報の取得
  echo "📋 環境情報を取得中..."
  local -r aws_account_id="$(aws sts get-caller-identity --query Account --output text)"
  local -r aws_region="$(aws configure get region)"
  
  echo "  AWS Account ID: ${aws_account_id}"
  echo "  AWS Region: ${aws_region}"
  echo ""
  
  # cdk-setupディレクトリへ移動
  cd "${cdk_setup_dir}"
  
  # 依存関係のインストール
  echo "📦 依存関係をインストール中..."
  if [ ! -d "node_modules" ]; then
    npm install
  else
    echo "  ✓ 依存関係は既にインストール済み"
  fi
  echo ""
  
  # TypeScriptのビルド
  echo "🔨 TypeScriptをビルド中..."
  npm run build
  echo ""
  
  # CloudFormationテンプレートの生成と確認
  echo "📄 CloudFormationテンプレートを生成中..."
  npx cdk synth
  echo ""
  
  # デプロイ前の確認
  echo "🔍 デプロイ内容を確認中..."
  npx cdk diff || true
  echo ""
  
  # デプロイの実行
  echo "🚀 Permissions BoundaryとDeny Policyをデプロイ中..."
  echo ""
  echo "  作成されるリソース:"
  echo "  - CDKPermissionsBoundary (IAM Policy)"
  echo "  - CDKDenyPolicy (IAM Policy)"
  echo ""
  
  # 確認プロンプト
  read -p "デプロイを実行しますか？ (y/N): " -r confirmation
  echo ""
  
  if [[ ! "${confirmation}" =~ ^[Yy]$ ]]; then
    echo "❌ デプロイをキャンセルしました"
    exit 0
  fi
  
  # CDKデプロイ
  npx cdk deploy --require-approval never
  echo ""
  
  # デプロイ結果の確認
  echo "✅ デプロイが完了しました"
  echo ""
  echo "📋 作成されたポリシー:"
  
  # Permissions Boundary ARNの取得と表示
  local permissions_boundary_arn
  permissions_boundary_arn=$(aws cloudformation describe-stacks \
    --stack-name CdkSetupStack \
    --query 'Stacks[0].Outputs[?OutputKey==`PermissionsBoundaryArn`].OutputValue' \
    --output text 2>/dev/null || echo "")
  
  if [ -n "${permissions_boundary_arn}" ]; then
    echo "  Permissions Boundary ARN:"
    echo "  ${permissions_boundary_arn}"
  fi
  
  # Deny Policy ARNの取得と表示
  local deny_policy_arn
  deny_policy_arn=$(aws cloudformation describe-stacks \
    --stack-name CdkSetupStack \
    --query 'Stacks[0].Outputs[?OutputKey==`DenyPolicyArn`].OutputValue' \
    --output text 2>/dev/null || echo "")
  
  if [ -n "${deny_policy_arn}" ]; then
    echo "  Deny Policy ARN:"
    echo "  ${deny_policy_arn}"
  fi
  
  echo ""
  echo "=========================================="
  echo "✨ セットアップが完了しました"
  echo "=========================================="
  echo ""
  echo "次のステップ:"
  echo "  1. Bootstrapを実行してください"
  echo "     → scripts/admin/02-bootstrap-with-qualifier.sh"
  echo ""
}

main "$@"
