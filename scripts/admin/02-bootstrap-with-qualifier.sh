#!/bin/bash
#
# 管理者用スクリプト: カスタムQualifierでのCDK Bootstrap実行
#
# このスクリプトは、CDKが使用するAWSリソース（S3バケット、ECRリポジトリ、IAMロール）を
# カスタムQualifier "pbdemo"で作成します。Qualifierにより環境ごとに異なるリソースを作成し、
# 物理的な分離を実現します。
#
# 実行前提条件:
# - AWS CLIがインストールされ、認証情報が設定されていること
# - AWS CDK CLIがインストールされていること
# - Permissions BoundaryとDeny Policyが既にデプロイされていること
#   （01-setup-permissions-boundary.shを実行済み）
# - 管理者権限を持つIAMロールまたはユーザーでログインしていること
#
# セキュリティ上の注意点:
# - カスタムQualifierにより、複数環境のリソースが物理的に分離されます
# - --custom-permissions-boundaryオプションにより、Bootstrap時に作成される
#   IAMロールにPermissions Boundaryが自動適用されます
# - Bootstrap実行は管理者のみが行うべきです
#
set -euo pipefail

# AWS環境情報を取得して表示
show_environment_info() {
  local -r qualifier="${1}"
  
  echo "📋 環境情報を取得中..."
  local -r aws_account_id="$(aws sts get-caller-identity --query Account --output text)"
  local -r aws_region="$(aws configure get region)"
  
  echo "  AWS Account ID: ${aws_account_id}"
  echo "  AWS Region: ${aws_region}"
  echo "  Qualifier: ${qualifier}"
  echo ""
  
  echo "${aws_account_id}:${aws_region}"
}

# Permissions Boundary ARNを取得
get_permissions_boundary_arn() {
  echo "🔍 Permissions Boundary ARNを取得中..."
  
  local permissions_boundary_arn
  permissions_boundary_arn=$(aws cloudformation describe-stacks \
    --stack-name CdkSetupStack \
    --query 'Stacks[0].Outputs[?OutputKey==`PermissionsBoundaryArn`].OutputValue' \
    --output text 2>/dev/null || echo "")
  
  if [ -z "${permissions_boundary_arn}" ]; then
    echo "❌ エラー: Permissions Boundaryが見つかりません"
    echo ""
    echo "先に以下のスクリプトを実行してください:"
    echo "  scripts/admin/01-setup-permissions-boundary.sh"
    echo ""
    return 1
  fi
  
  echo "  Permissions Boundary ARN:"
  echo "  ${permissions_boundary_arn}"
  echo ""
  
  echo "${permissions_boundary_arn}"
}

# Bootstrap実行内容を説明
show_bootstrap_info() {
  local -r qualifier="${1}"
  local -r aws_account_id="${2}"
  local -r aws_region="${3}"
  
  echo "📦 Bootstrap実行内容:"
  echo ""
  echo "  作成されるリソース:"
  echo "  - S3バケット: cdk-${qualifier}-assets-${aws_account_id}-${aws_region}"
  echo "  - ECRリポジトリ: cdk-${qualifier}-container-assets-${aws_account_id}-${aws_region}"
  echo "  - IAMロール: Deployment Action Role (Permissions Boundary適用済み)"
  echo "  - IAMロール: CloudFormation Execution Role (Permissions Boundary適用済み)"
  echo "  - CloudFormationスタック: CDKToolkit-${qualifier}"
  echo ""
}

# Bootstrap実行の確認
confirm_bootstrap() {
  local confirmation
  read -p "Bootstrapを実行しますか？ (y/N): " -r confirmation
  echo ""
  
  [[ "${confirmation}" =~ ^[Yy]$ ]]
}

# Bootstrapを実行
execute_bootstrap() {
  local -r qualifier="${1}"
  local -r permissions_boundary_arn="${2}"
  local -r aws_account_id="${3}"
  local -r aws_region="${4}"
  
  echo "🚀 Bootstrapを実行中..."
  echo ""
  
  cdk bootstrap \
    --qualifier "${qualifier}" \
    --toolkit-stack-name "CDKToolkit-${qualifier}" \
    --custom-permissions-boundary "${permissions_boundary_arn}" \
    "aws://${aws_account_id}/${aws_region}"
  
  echo ""
  echo "✅ Bootstrapが完了しました"
  echo ""
}

# S3バケットの存在を確認
check_s3_bucket() {
  local -r bucket_name="${1}"
  
  if aws s3 ls "s3://${bucket_name}" >/dev/null 2>&1; then
    echo "  ✓ S3バケット: ${bucket_name}"
  fi
}

# ECRリポジトリの存在を確認
check_ecr_repository() {
  local -r repo_name="${1}"
  
  if aws ecr describe-repositories --repository-names "${repo_name}" >/dev/null 2>&1; then
    echo "  ✓ ECRリポジトリ: ${repo_name}"
  fi
}

# CloudFormationスタックの存在を確認
check_cloudformation_stack() {
  local -r stack_name="${1}"
  
  if aws cloudformation describe-stacks --stack-name "${stack_name}" >/dev/null 2>&1; then
    echo "  ✓ CloudFormationスタック: ${stack_name}"
  fi
}

# 作成されたリソースを確認
verify_created_resources() {
  local -r qualifier="${1}"
  local -r aws_account_id="${2}"
  local -r aws_region="${3}"
  
  echo "📋 作成されたリソース:"
  echo ""
  
  check_s3_bucket "cdk-${qualifier}-assets-${aws_account_id}-${aws_region}"
  check_ecr_repository "cdk-${qualifier}-container-assets-${aws_account_id}-${aws_region}"
  check_cloudformation_stack "CDKToolkit-${qualifier}"
  
  echo ""
}

# Permissions Boundary適用を確認
verify_permissions_boundary() {
  local -r qualifier="${1}"
  
  echo "🔐 セキュリティ設定の確認:"
  echo ""
  
  local -r cfn_exec_role_arn=$(aws cloudformation describe-stacks \
    --stack-name "CDKToolkit-${qualifier}" \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFormationExecutionRoleArn`].OutputValue' \
    --output text 2>/dev/null || echo "")
  
  if [ -n "${cfn_exec_role_arn}" ]; then
    local -r role_name="${cfn_exec_role_arn##*/}"
    local exec_pb
    exec_pb=$(aws iam get-role \
      --role-name "${role_name}" \
      --query 'Role.PermissionsBoundary.PermissionsBoundaryArn' \
      --output text 2>/dev/null || echo "None")
    
    if [ "${exec_pb}" != "None" ]; then
      echo "  ✓ CloudFormation Execution Role: Permissions Boundary適用済み"
    else
      echo "  ⚠️  CloudFormation Execution Role: Permissions Boundary未適用"
    fi
  fi
  
  echo ""
}

# 次のステップを表示
show_next_steps() {
  echo "=========================================="
  echo "✨ Bootstrapが完了しました"
  echo "=========================================="
  echo ""
  echo "次のステップ:"
  echo "  開発者は以下のコマンドでアプリケーションをデプロイできます:"
  echo "  → scripts/developer/02-deploy-app.sh"
  echo ""
}

# メイン処理
main() {
  local -r qualifier="${1:-pbdemo}"
  
  echo "=========================================="
  echo "CDK Bootstrap (Qualifier: ${qualifier})"
  echo "=========================================="
  echo ""
  
  local -r env_info="$(show_environment_info "${qualifier}")"
  local -r aws_account_id="${env_info%%:*}"
  local -r aws_region="${env_info##*:}"
  
  local -r permissions_boundary_arn="$(get_permissions_boundary_arn)" || return 1
  
  show_bootstrap_info "${qualifier}" "${aws_account_id}" "${aws_region}"
  
  if ! confirm_bootstrap; then
    echo "❌ Bootstrapをキャンセルしました"
    return 0
  fi
  
  execute_bootstrap "${qualifier}" "${permissions_boundary_arn}" "${aws_account_id}" "${aws_region}"
  verify_created_resources "${qualifier}" "${aws_account_id}" "${aws_region}"
  verify_permissions_boundary "${qualifier}"
  show_next_steps
}

main "$@"
