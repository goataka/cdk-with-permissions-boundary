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

# プロジェクトルートディレクトリを取得
get_project_root() {
  local -r script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "${script_dir}/../.." && pwd
}

# AWS環境情報を取得して表示
show_environment_info() {
  echo "📋 環境情報を取得中..."
  local -r aws_account_id="$(aws sts get-caller-identity --query Account --output text)"
  local -r aws_region="$(aws configure get region)"
  
  echo "  AWS Account ID: ${aws_account_id}"
  echo "  AWS Region: ${aws_region}"
  echo ""
}

# 依存関係をインストール
install_dependencies() {
  local -r cdk_dir="${1}"
  
  cd "${cdk_dir}"
  echo "📦 依存関係をインストール中..."
  
  if [ ! -d "node_modules" ]; then
    npm install
  else
    echo "  ✓ 依存関係は既にインストール済み"
  fi
  echo ""
}

# TypeScriptをビルド
build_typescript() {
  echo "🔨 TypeScriptをビルド中..."
  npm run build
  echo ""
}

# CloudFormationテンプレートを生成
generate_template() {
  echo "📄 CloudFormationテンプレートを生成中..."
  npx cdk synth
  echo ""
}

# デプロイ前の差分を確認
show_deployment_diff() {
  echo "🔍 デプロイ内容を確認中..."
  npx cdk diff || true
  echo ""
}

# デプロイ内容を表示
show_deployment_info() {
  echo "🚀 Permissions BoundaryとDeny Policyをデプロイ中..."
  echo ""
  echo "  作成されるリソース:"
  echo "  - CDKPermissionsBoundary (IAM Policy)"
  echo "  - CDKDenyPolicy (IAM Policy)"
  echo ""
}

# デプロイ実行の確認
confirm_deployment() {
  local confirmation
  read -p "デプロイを実行しますか？ (y/N): " -r confirmation
  echo ""
  
  [[ "${confirmation}" =~ ^[Yy]$ ]]
}

# CDKスタックをデプロイ
deploy_stack() {
  npx cdk deploy --require-approval never
  echo ""
}

# デプロイされたポリシーのARNを取得
get_policy_arn() {
  local -r output_key="${1}"
  
  aws cloudformation describe-stacks \
    --stack-name CdkSetupStack \
    --query "Stacks[0].Outputs[?OutputKey==\`${output_key}\`].OutputValue" \
    --output text 2>/dev/null || echo ""
}

# デプロイ結果を表示
show_deployment_results() {
  echo "✅ デプロイが完了しました"
  echo ""
  echo "📋 作成されたポリシー:"
  
  local -r permissions_boundary_arn="$(get_policy_arn "PermissionsBoundaryArn")"
  if [ -n "${permissions_boundary_arn}" ]; then
    echo "  Permissions Boundary ARN:"
    echo "  ${permissions_boundary_arn}"
  fi
  
  local -r deny_policy_arn="$(get_policy_arn "DenyPolicyArn")"
  if [ -n "${deny_policy_arn}" ]; then
    echo "  Deny Policy ARN:"
    echo "  ${deny_policy_arn}"
  fi
  
  echo ""
}

# 次のステップを表示
show_next_steps() {
  echo "=========================================="
  echo "✨ セットアップが完了しました"
  echo "=========================================="
  echo ""
  echo "次のステップ:"
  echo "  1. Bootstrapを実行してください"
  echo "     → scripts/admin/02-bootstrap-with-qualifier.sh"
  echo ""
}

# メイン処理
main() {
  local -r project_root="$(get_project_root)"
  local -r cdk_setup_dir="${project_root}/cdk-setup"
  
  echo "=========================================="
  echo "Permissions Boundary セットアップ"
  echo "=========================================="
  echo ""
  
  show_environment_info
  install_dependencies "${cdk_setup_dir}"
  build_typescript
  generate_template
  show_deployment_diff
  show_deployment_info
  
  if ! confirm_deployment; then
    echo "❌ デプロイをキャンセルしました"
    return 0
  fi
  
  deploy_stack
  show_deployment_results
  show_next_steps
}

main "$@"
