$ErrorActionPreference = "Continue"
$AWS = "C:\Program Files\Amazon\AWSCLIV2\aws.exe"
$Region = "us-east-1"
$TableName = "ai-task-assistant-tasks"
$RoleName = "TaskAssistantLambdaRole"
$OpenAIKey = "$env:OPENAI_API_KEY"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Deploying AI Task Assistant to AWS (Windows)  " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Get Account ID
$AccountId = (& $AWS sts get-caller-identity --query Account --output text).Trim()
Write-Host "AWS Account ID: $AccountId" -ForegroundColor Green

# 1. DynamoDB Table
Write-Host "`n[1/6] Creating DynamoDB Table..." -ForegroundColor Yellow
& $AWS dynamodb create-table --table-name $TableName --attribute-definitions AttributeName=id,AttributeType=S --key-schema AttributeName=id,KeyType=HASH --billing-mode PAY_PER_REQUEST --region $Region 2>$null
Write-Host "DynamoDB Table Ready" -ForegroundColor Green

# 2. IAM Role
Write-Host "`n[2/6] Creating IAM Role..." -ForegroundColor Yellow
$TrustPolicy = '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
$TrustPolicyPath = "$env:TEMP\trust-policy.json"
Set-Content -Path $TrustPolicyPath -Value $TrustPolicy

& $AWS iam create-role --role-name $RoleName --assume-role-policy-document "file://$TrustPolicyPath" 2>$null
& $AWS iam attach-role-policy --role-name $RoleName --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" 2>$null

$DynamoPolicy = '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["dynamodb:*"],"Resource":"arn:aws:dynamodb:*:*:table/ai-task-assistant-tasks*"}]}'
$DynamoPolicyPath = "$env:TEMP\dynamodb-policy.json"
Set-Content -Path $DynamoPolicyPath -Value $DynamoPolicy

& $AWS iam put-role-policy --role-name $RoleName --policy-name "DynamoDBAccess" --policy-document "file://$DynamoPolicyPath" 2>$null

$RoleArn = (& $AWS iam get-role --role-name $RoleName --query 'Role.Arn' --output text).Trim()
Write-Host "IAM Role ARN: $RoleArn" -ForegroundColor Green

Write-Host "Waiting 10s for IAM propagation..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# 3. Package & Deploy Lambda Functions
Write-Host "`n[3/6] Packaging and Deploying Lambda Functions..." -ForegroundColor Yellow

$DeployDir = "$PSScriptRoot\deployment_packages"
New-Item -ItemType Directory -Force -Path $DeployDir | Out-Null

Compress-Archive -Path "$PSScriptRoot\backend\lambda_functions\task_handler.py" -DestinationPath "$DeployDir\task_handler.zip" -Force
Compress-Archive -Path "$PSScriptRoot\backend\lambda_functions\ai_chat_handler.py" -DestinationPath "$DeployDir\ai_chat_handler.zip" -Force

& $AWS lambda create-function --function-name "ai-task-assistant-task-handler" --runtime "python3.11" --role $RoleArn --handler "task_handler.lambda_handler" --zip-file "fileb://$DeployDir\task_handler.zip" --timeout 30 --memory-size 256 --region $Region 2>$null
if ($LASTEXITCODE -ne 0) {
    & $AWS lambda update-function-code --function-name "ai-task-assistant-task-handler" --zip-file "fileb://$DeployDir\task_handler.zip" --region $Region | Out-Null
}
Write-Host "Task Handler Lambda Deployed" -ForegroundColor Green

& $AWS lambda create-function --function-name "ai-task-assistant-chat-handler" --runtime "python3.11" --role $RoleArn --handler "ai_chat_handler.lambda_handler" --zip-file "fileb://$DeployDir\ai_chat_handler.zip" --timeout 30 --memory-size 512 --region $Region 2>$null
if ($LASTEXITCODE -ne 0) {
    & $AWS lambda update-function-code --function-name "ai-task-assistant-chat-handler" --zip-file "fileb://$DeployDir\ai_chat_handler.zip" --region $Region | Out-Null
}
Write-Host "Chat Handler Lambda Deployed" -ForegroundColor Green

& $AWS lambda update-function-configuration --function-name "ai-task-assistant-chat-handler" --environment "Variables={OPENAI_API_KEY=$OpenAIKey}" --region $Region | Out-Null
Write-Host "OpenAI API Key Configured on Chat Handler" -ForegroundColor Green

# 4. API Gateway Setup
Write-Host "`n[4/6] Creating REST API Gateway..." -ForegroundColor Yellow

$ApiId = (& $AWS apigateway get-rest-apis --region $Region --query "items[?name=='ai-task-assistant-api'].id" --output text).Trim()
if ([string]::IsNullOrWhitespace($ApiId) -or $ApiId -eq "None") {
    $ApiId = (& $AWS apigateway create-rest-api --name "ai-task-assistant-api" --description "API for AI Task Assistant" --region $Region --query 'id' --output text).Trim()
}
Write-Host "REST API ID: $ApiId" -ForegroundColor Green

$RootId = (& $AWS apigateway get-resources --rest-api-id $ApiId --region $Region --query "items[?path=='/'].id" --output text).Trim()

$TasksResourceId = (& $AWS apigateway get-resources --rest-api-id $ApiId --region $Region --query "items[?pathPart=='tasks'].id" --output text).Trim()
if ([string]::IsNullOrWhitespace($TasksResourceId) -or $TasksResourceId -eq "None") {
    $TasksResourceId = (& $AWS apigateway create-resource --rest-api-id $ApiId --parent-id $RootId --path-part "tasks" --region $Region --query 'id' --output text).Trim()
}

& $AWS apigateway put-method --rest-api-id $ApiId --resource-id $TasksResourceId --http-method POST --authorization-type NONE --region $Region 2>$null
& $AWS apigateway put-integration --rest-api-id $ApiId --resource-id $TasksResourceId --http-method POST --type AWS_PROXY --integration-http-method POST --uri "arn:aws:apigateway:${Region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${Region}:${AccountId}:function:ai-task-assistant-task-handler/invocations" --region $Region 2>$null

& $AWS apigateway put-method --rest-api-id $ApiId --resource-id $TasksResourceId --http-method GET --authorization-type NONE --region $Region 2>$null
& $AWS apigateway put-integration --rest-api-id $ApiId --resource-id $TasksResourceId --http-method GET --type AWS_PROXY --integration-http-method POST --uri "arn:aws:apigateway:${Region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${Region}:${AccountId}:function:ai-task-assistant-task-handler/invocations" --region $Region 2>$null

$TaskIdResourceId = (& $AWS apigateway get-resources --rest-api-id $ApiId --region $Region --query "items[?pathPart=='{id}'].id" --output text).Trim()
if ([string]::IsNullOrWhitespace($TaskIdResourceId) -or $TaskIdResourceId -eq "None") {
    $TaskIdResourceId = (& $AWS apigateway create-resource --rest-api-id $ApiId --parent-id $TasksResourceId --path-part "{id}" --region $Region --query 'id' --output text).Trim()
}

foreach ($method in @("GET", "PUT", "DELETE")) {
    & $AWS apigateway put-method --rest-api-id $ApiId --resource-id $TaskIdResourceId --http-method $method --authorization-type NONE --region $Region 2>$null
    & $AWS apigateway put-integration --rest-api-id $ApiId --resource-id $TaskIdResourceId --http-method $method --type AWS_PROXY --integration-http-method POST --uri "arn:aws:apigateway:${Region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${Region}:${AccountId}:function:ai-task-assistant-task-handler/invocations" --region $Region 2>$null
}

$ChatResourceId = (& $AWS apigateway get-resources --rest-api-id $ApiId --region $Region --query "items[?pathPart=='chat'].id" --output text).Trim()
if ([string]::IsNullOrWhitespace($ChatResourceId) -or $ChatResourceId -eq "None") {
    $ChatResourceId = (& $AWS apigateway create-resource --rest-api-id $ApiId --parent-id $RootId --path-part "chat" --region $Region --query 'id' --output text).Trim()
}

& $AWS apigateway put-method --rest-api-id $ApiId --resource-id $ChatResourceId --http-method POST --authorization-type NONE --region $Region 2>$null
& $AWS apigateway put-integration --rest-api-id $ApiId --resource-id $ChatResourceId --http-method POST --type AWS_PROXY --integration-http-method POST --uri "arn:aws:apigateway:${Region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${Region}:${AccountId}:function:ai-task-assistant-chat-handler/invocations" --region $Region 2>$null

# 5. Lambda Permissions
Write-Host "`n[5/6] Adding Lambda Permissions..." -ForegroundColor Yellow
& $AWS lambda add-permission --function-name "ai-task-assistant-task-handler" --statement-id "apigateway-tasks" --action "lambda:InvokeFunction" --principal "apigateway.amazonaws.com" --source-arn "arn:aws:execute-api:${Region}:${AccountId}:${ApiId}/*/*/*" --region $Region 2>$null
& $AWS lambda add-permission --function-name "ai-task-assistant-chat-handler" --statement-id "apigateway-chat" --action "lambda:InvokeFunction" --principal "apigateway.amazonaws.com" --source-arn "arn:aws:execute-api:${Region}:${AccountId}:${ApiId}/*/*/*" --region $Region 2>$null

# 6. Deploy API Gateway to 'prod'
Write-Host "`n[6/6] Deploying API to stage 'prod'..." -ForegroundColor Yellow
& $AWS apigateway create-deployment --rest-api-id $ApiId --stage-name "prod" --region $Region | Out-Null

$ApiUrl = "https://${ApiId}.execute-api.${Region}.amazonaws.com/prod"

Write-Host "`n================================================" -ForegroundColor Green
Write-Host " AWS DEPLOYMENT COMPLETE! " -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host "Your Base API URL: $ApiUrl" -ForegroundColor Cyan

Set-Content -Path "$PSScriptRoot\.env.local" -Value "# Frontend API Gateway URL`nNEXT_PUBLIC_API_BASE_URL=$ApiUrl`n`n# Backend OpenAI API Key`nOPENAI_API_KEY=$OpenAIKey"
Write-Host "Saved to .env.local!" -ForegroundColor Green
