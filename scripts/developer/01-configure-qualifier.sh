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

# メイン処理
main() {
  local -r script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local -r project_root="$(cd "${script_dir}/../.." && pwd)"
  local -r cdk_app_dir="${project_root}/cdk-app"
  local -r cdk_json="${cdk_app_dir}/cdk.json"
  
  echo "=========================================="
  echo "Qualifier設定の確認"
  echo "=========================================="
  echo ""
  
  # cdk.jsonの存在確認
  if [ ! -f "${cdk_json}" ]; then
    echo "❌ エラー: cdk.jsonが見つかりません"
    echo "  パス: ${cdk_json}"
    exit 1
  fi
  
  # Qualifierの取得
  echo "📋 現在の設定を確認中..."
  
  local qualifier
  if command -v jq >/dev/null 2>&1; then
    qualifier=$(jq -r '.context."@aws-cdk/core:bootstrapQualifier" // "default"' "${cdk_json}")
  else
    # jqがない場合は grep で取得（簡易版）
    qualifier=$(grep -o '"@aws-cdk/core:bootstrapQualifier"[[:space:]]*:[[:space:]]*"[^"]*"' "${cdk_json}" | sed 's/.*"\([^"]*\)"$/\1/' || echo "default")
  fi
  
  echo "  Qualifier: ${qualifier}"
  echo ""
  
  # Permissions Boundary設定の確認
  local pb_name
  if command -v jq >/dev/null 2>&1; then
    pb_name=$(jq -r '.context."@aws-cdk/core:permissionsBoundary".name // "未設定"' "${cdk_json}")
  else
    pb_name=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "${cdk_json}" | head -1 | sed 's/.*"\([^"]*\)"$/\1/' || echo "未設定")
  fi
  
  echo "  Permissions Boundary: ${pb_name}"
  echo ""
  
  # Bootstrap状態の確認
  echo "🔍 Bootstrap状態を確認中..."
  
  local -r aws_account_id="$(aws sts get-caller-identity --query Account --output text)"
  local -r aws_region="$(aws configure get region)"
  
  echo "  AWS Account ID: ${aws_account_id}"
  echo "  AWS Region: ${aws_region}"
  echo ""
  
  # Bootstrapスタックの存在確認
  local -r stack_name="CDKToolkit-${qualifier}"
  if aws cloudformation describe-stacks --stack-name "${stack_name}" >/dev/null 2>&1; then
    echo "  ✓ Bootstrapスタック '${stack_name}' が存在します"
    
    # スタックの状態を確認
    local -r stack_status=$(aws cloudformation describe-stacks \
      --stack-name "${stack_name}" \
      --query 'Stacks[0].StackStatus' \
      --output text)
    
    echo "  スタック状態: ${stack_status}"
    
    if [[ "${stack_status}" == "CREATE_COMPLETE" ]] || [[ "${stack_status}" == "UPDATE_COMPLETE" ]]; then
      echo ""
      echo "✅ Qualifier設定は正しく、Bootstrapも完了しています"
      echo ""
      echo "次のステップ:"
      echo "  アプリケーションをデプロイできます:"
      echo "  → scripts/developer/02-deploy-app.sh"
    else
      echo ""
      echo "⚠️  警告: Bootstrapスタックの状態が異常です"
      echo "  管理者に連絡してください"
    fi
  else
    echo "  ❌ Bootstrapスタック '${stack_name}' が見つかりません"
    echo ""
    echo "管理者にBootstrapの実行を依頼してください:"
    echo "  → scripts/admin/02-bootstrap-with-qualifier.sh ${qualifier}"
  fi
  
  echo ""
  echo "=========================================="
  echo "確認完了"
  echo "=========================================="
  echo ""
}

main "$@"
