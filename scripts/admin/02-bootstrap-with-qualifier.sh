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

# メイン処理
main() {
  local -r qualifier="${1:-pbdemo}"
  
  echo "=========================================="
  echo "CDK Bootstrap (Qualifier: ${qualifier})"
  echo "=========================================="
  echo ""
  
  # 環境情報の取得
  echo "📋 環境情報を取得中..."
  local -r aws_account_id="$(aws sts get-caller-identity --query Account --output text)"
  local -r aws_region="$(aws configure get region)"
  
  echo "  AWS Account ID: ${aws_account_id}"
  echo "  AWS Region: ${aws_region}"
  echo "  Qualifier: ${qualifier}"
  echo ""
  
  # Permissions Boundary ARNの取得
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
    exit 1
  fi
  
  echo "  Permissions Boundary ARN:"
  echo "  ${permissions_boundary_arn}"
  echo ""
  
  # Bootstrap実行内容の説明
  echo "📦 Bootstrap実行内容:"
  echo ""
  echo "  作成されるリソース:"
  echo "  - S3バケット: cdk-${qualifier}-assets-${aws_account_id}-${aws_region}"
  echo "  - ECRリポジトリ: cdk-${qualifier}-container-assets-${aws_account_id}-${aws_region}"
  echo "  - IAMロール: Deployment Action Role (Permissions Boundary適用済み)"
  echo "  - IAMロール: CloudFormation Execution Role (Permissions Boundary適用済み)"
  echo "  - CloudFormationスタック: CDKToolkit-${qualifier}"
  echo ""
  
  # 確認プロンプト
  read -p "Bootstrapを実行しますか？ (y/N): " -r confirmation
  echo ""
  
  if [[ ! "${confirmation}" =~ ^[Yy]$ ]]; then
    echo "❌ Bootstrapをキャンセルしました"
    exit 0
  fi
  
  # Bootstrap実行
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
  
  # 作成されたリソースの確認
  echo "📋 作成されたリソース:"
  echo ""
  
  # S3バケットの確認
  local -r s3_bucket="cdk-${qualifier}-assets-${aws_account_id}-${aws_region}"
  if aws s3 ls "s3://${s3_bucket}" >/dev/null 2>&1; then
    echo "  ✓ S3バケット: ${s3_bucket}"
  fi
  
  # ECRリポジトリの確認
  local -r ecr_repo="cdk-${qualifier}-container-assets-${aws_account_id}-${aws_region}"
  if aws ecr describe-repositories --repository-names "${ecr_repo}" >/dev/null 2>&1; then
    echo "  ✓ ECRリポジトリ: ${ecr_repo}"
  fi
  
  # CloudFormationスタックの確認
  if aws cloudformation describe-stacks --stack-name "CDKToolkit-${qualifier}" >/dev/null 2>&1; then
    echo "  ✓ CloudFormationスタック: CDKToolkit-${qualifier}"
  fi
  
  echo ""
  echo "🔐 セキュリティ設定の確認:"
  echo ""
  
  # CloudFormation Execution RoleのPermissions Boundary確認
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
  echo "=========================================="
  echo "✨ Bootstrapが完了しました"
  echo "=========================================="
  echo ""
  echo "次のステップ:"
  echo "  開発者は以下のコマンドでアプリケーションをデプロイできます:"
  echo "  → scripts/developer/02-deploy-app.sh"
  echo ""
}

main "$@"
