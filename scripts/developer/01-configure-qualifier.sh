#!/bin/bash
#
# 開発者用スクリプト: Qualifier設定の確認
#
# このスクリプトは、cdk.jsonに正しいQualifierが設定されているかを確認します。
# Qualifierは環境分離のために必須の設定項目です。
#
# 実行前提条件:
# - 管理者がBootstrapを完了していること（02-bootstrap-with-qualifier.sh実行済み）
#
# セキュリティ上の注意点:
# - Qualifierは環境ごとに異なる値を使用してください（開発: pbdemo, 本番: pbprod など）
# - 誤ったQualifierを使用すると、意図しない環境にデプロイされる可能性があります
#
set -euo pipefail

# プロジェクトルートディレクトリを取得
get_project_root() {
  local -r script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "${script_dir}/../.." && pwd
}

# cdk.jsonの存在を確認
check_cdk_json_exists() {
  local -r cdk_json="${1}"
  
  if [ ! -f "${cdk_json}" ]; then
    echo "❌ エラー: cdk.jsonが見つかりません"
    echo "  パス: ${cdk_json}"
    return 1
  fi
}

# Qualifierを取得
get_qualifier() {
  local -r cdk_json="${1}"
  
  if command -v jq >/dev/null 2>&1; then
    jq -r '.context."@aws-cdk/core:bootstrapQualifier" // "default"' "${cdk_json}"
  else
    grep -o '"@aws-cdk/core:bootstrapQualifier"[[:space:]]*:[[:space:]]*"[^"]*"' "${cdk_json}" | \
      sed 's/.*"\([^"]*\)"$/\1/' || echo "default"
  fi
}

# Permissions Boundary名を取得
get_permissions_boundary_name() {
  local -r cdk_json="${1}"
  
  if command -v jq >/dev/null 2>&1; then
    jq -r '.context."@aws-cdk/core:permissionsBoundary".name // "未設定"' "${cdk_json}"
  else
    grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "${cdk_json}" | \
      head -1 | sed 's/.*"\([^"]*\)"$/\1/' || echo "未設定"
  fi
}

# 現在の設定を表示
show_current_settings() {
  local -r cdk_json="${1}"
  
  echo "📋 現在の設定を確認中..."
  
  local -r qualifier="$(get_qualifier "${cdk_json}")"
  echo "  Qualifier: ${qualifier}"
  echo ""
  
  local -r pb_name="$(get_permissions_boundary_name "${cdk_json}")"
  echo "  Permissions Boundary: ${pb_name}"
  echo ""
  
  echo "${qualifier}"
}

# AWS環境情報を取得して表示
show_aws_environment() {
  echo "🔍 Bootstrap状態を確認中..."
  
  local -r aws_account_id="$(aws sts get-caller-identity --query Account --output text)"
  local -r aws_region="$(aws configure get region)"
  
  echo "  AWS Account ID: ${aws_account_id}"
  echo "  AWS Region: ${aws_region}"
  echo ""
}

# Bootstrapスタックの状態を取得
get_bootstrap_stack_status() {
  local -r stack_name="${1}"
  
  aws cloudformation describe-stacks \
    --stack-name "${stack_name}" \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null || echo ""
}

# Bootstrapスタックの状態を確認
verify_bootstrap_stack() {
  local -r qualifier="${1}"
  local -r stack_name="CDKToolkit-${qualifier}"
  
  if ! aws cloudformation describe-stacks --stack-name "${stack_name}" >/dev/null 2>&1; then
    echo "  ❌ Bootstrapスタック '${stack_name}' が見つかりません"
    echo ""
    echo "管理者にBootstrapの実行を依頼してください:"
    echo "  → scripts/admin/02-bootstrap-with-qualifier.sh ${qualifier}"
    return 1
  fi
  
  echo "  ✓ Bootstrapスタック '${stack_name}' が存在します"
  
  local -r stack_status="$(get_bootstrap_stack_status "${stack_name}")"
  echo "  スタック状態: ${stack_status}"
  
  if [[ "${stack_status}" == "CREATE_COMPLETE" ]] || [[ "${stack_status}" == "UPDATE_COMPLETE" ]]; then
    return 0
  else
    echo ""
    echo "⚠️  警告: Bootstrapスタックの状態が異常です"
    echo "  管理者に連絡してください"
    return 1
  fi
}

# 成功時の次ステップを表示
show_success_message() {
  echo ""
  echo "✅ Qualifier設定は正しく、Bootstrapも完了しています"
  echo ""
  echo "次のステップ:"
  echo "  アプリケーションをデプロイできます:"
  echo "  → scripts/developer/02-deploy-app.sh"
}

# 完了メッセージを表示
show_completion_message() {
  echo ""
  echo "=========================================="
  echo "確認完了"
  echo "=========================================="
  echo ""
}

# メイン処理
main() {
  local -r project_root="$(get_project_root)"
  local -r cdk_app_dir="${project_root}/cdk-app"
  local -r cdk_json="${cdk_app_dir}/cdk.json"
  
  echo "=========================================="
  echo "Qualifier設定の確認"
  echo "=========================================="
  echo ""
  
  check_cdk_json_exists "${cdk_json}" || return 1
  
  local -r qualifier="$(show_current_settings "${cdk_json}")"
  show_aws_environment
  
  if verify_bootstrap_stack "${qualifier}"; then
    show_success_message
  fi
  
  show_completion_message
}

main "$@"
