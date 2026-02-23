#!/bin/bash
#
# 開発者用スクリプト: CDKアプリケーションのデプロイ
#
# このスクリプトは、Permissions Boundary制約下でCDKアプリケーションをデプロイします。
# デプロイ前にCDK Aspectsによるセキュリティ検証が実行されます。
#
# 実行前提条件:
# - AWS CLIがインストールされ、認証情報が設定されていること
# - AWS CDK CLIがインストールされていること
# - Node.js 18.x以上がインストールされていること
# - 管理者がPermissions BoundaryとBootstrapを完了していること
# - 開発者ロール（DeployRole）の権限があること
#
# セキュリティ上の注意点:
# - デプロイされる全てのIAMロールにPermissions Boundaryが自動適用されます
# - CDK Aspectsにより、セキュアでない設定は自動的に検出・ブロックされます
# - S3バケットは必ず暗号化され、パブリックアクセスがブロックされます
#
set -euo pipefail

# メイン処理
main() {
  local -r script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local -r project_root="$(cd "${script_dir}/../.." && pwd)"
  local -r cdk_app_dir="${project_root}/cdk-app"
  
  echo "=========================================="
  echo "CDKアプリケーションのデプロイ"
  echo "=========================================="
  echo ""
  
  # 環境情報の取得
  echo "📋 環境情報を取得中..."
  local -r aws_account_id="$(aws sts get-caller-identity --query Account --output text)"
  local -r aws_region="$(aws configure get region)"
  
  echo "  AWS Account ID: ${aws_account_id}"
  echo "  AWS Region: ${aws_region}"
  echo ""
  
  # cdk-appディレクトリへ移動
  cd "${cdk_app_dir}"
  
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
  
  # テストの実行
  echo "🧪 テストを実行中..."
  npm test
  echo ""
  
  # CloudFormationテンプレートの生成とAspects検証
  echo "📄 CloudFormationテンプレートを生成中..."
  echo "  （CDK Aspectsによるセキュリティ検証を実行）"
  echo ""
  
  npx cdk synth
  echo ""
  
  # デプロイ前の差分確認
  echo "🔍 デプロイ内容を確認中..."
  npx cdk diff || true
  echo ""
  
  # デプロイの実行
  echo "🚀 アプリケーションをデプロイ中..."
  echo ""
  echo "  デプロイされるリソース:"
  echo "  - Lambda関数（Permissions Boundary適用済みロール）"
  echo "  - S3バケット（暗号化・バージョニング・パブリックアクセスブロック）"
  echo "  - カスタムIAMロール（Permissions Boundary適用済み）"
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
  
  # スタック出力の取得と表示
  echo "📋 デプロイされたリソース:"
  echo ""
  
  # Bucket Name
  local bucket_name
  bucket_name=$(aws cloudformation describe-stacks \
    --stack-name CdkAppStack \
    --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' \
    --output text 2>/dev/null || echo "")
  
  if [ -n "${bucket_name}" ]; then
    echo "  S3バケット: ${bucket_name}"
  fi
  
  # Lambda Function Name
  local function_name
  function_name=$(aws cloudformation describe-stacks \
    --stack-name CdkAppStack \
    --query 'Stacks[0].Outputs[?OutputKey==`FunctionName`].OutputValue' \
    --output text 2>/dev/null || echo "")
  
  if [ -n "${function_name}" ]; then
    echo "  Lambda関数: ${function_name}"
  fi
  
  echo ""
  
  # セキュリティ設定の確認
  echo "🔐 セキュリティ設定の確認:"
  echo ""
  
  # S3バケットの暗号化確認
  if [ -n "${bucket_name}" ]; then
    if aws s3api get-bucket-encryption --bucket "${bucket_name}" >/dev/null 2>&1; then
      echo "  ✓ S3バケット '${bucket_name}': 暗号化設定済み"
    else
      echo "  ⚠️  S3バケット '${bucket_name}': 暗号化未設定"
    fi
    
    # パブリックアクセスブロック確認
    if aws s3api get-public-access-block --bucket "${bucket_name}" >/dev/null 2>&1; then
      echo "  ✓ S3バケット '${bucket_name}': パブリックアクセスブロック設定済み"
    fi
  fi
  
  # Lambda関数のロール確認
  if [ -n "${function_name}" ]; then
    local lambda_role
    lambda_role=$(aws lambda get-function \
      --function-name "${function_name}" \
      --query 'Configuration.Role' \
      --output text 2>/dev/null || echo "")
    
    if [ -n "${lambda_role}" ]; then
      local -r role_name="${lambda_role##*/}"
      local pb_arn
      pb_arn=$(aws iam get-role \
        --role-name "${role_name}" \
        --query 'Role.PermissionsBoundary.PermissionsBoundaryArn' \
        --output text 2>/dev/null || echo "None")
      
      if [ "${pb_arn}" != "None" ]; then
        echo "  ✓ Lambda関数ロール: Permissions Boundary適用済み"
      else
        echo "  ⚠️  Lambda関数ロール: Permissions Boundary未適用"
      fi
    fi
  fi
  
  echo ""
  echo "=========================================="
  echo "✨ デプロイが完了しました"
  echo "=========================================="
  echo ""
  
  # 動作確認の案内
  if [ -n "${function_name}" ]; then
    echo "💡 動作確認:"
    echo ""
    echo "  Lambda関数を実行:"
    echo "  $ aws lambda invoke \\"
    echo "      --function-name ${function_name} \\"
    echo "      --payload '{}' \\"
    echo "      response.json"
    echo "  $ cat response.json"
    echo ""
  fi
  
  if [ -n "${bucket_name}" ]; then
    echo "  S3バケットにファイルをアップロード:"
    echo "  $ echo 'test' > test.txt"
    echo "  $ aws s3 cp test.txt s3://${bucket_name}/test.txt"
    echo "  $ aws s3 ls s3://${bucket_name}/"
    echo ""
  fi
}

main "$@"
