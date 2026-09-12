#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║   AI Task Assistant - AWS Deployment                  ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}"

REGION="us-east-1"
TABLE_NAME="ai-task-assistant-tasks"
ROLE_NAME="TaskAssistantLambdaRole"
PROJECT_DIR="$(pwd)"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not found${NC}"
    exit 1
fi

# Check credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured${NC}"
    exit 1
fi

echo -e "${GREEN}✅ AWS CLI configured${NC}\n"

# Confirmation
read -p "Deploy to AWS? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# 1. Create DynamoDB Table
echo -e "\n${BLUE}[1/5] Creating DynamoDB Table...${NC}"
aws dynamodb create-table \
    --table-name ${TABLE_NAME} \
    --attribute-definitions AttributeName=id,AttributeType=S \
    --key-schema AttributeName=id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region ${REGION} 2>/dev/null || echo "Table already exists"

echo -e "${GREEN}✅ DynamoDB table ready${NC}"

# 2. Create IAM Role
echo -e "\n${BLUE}[2/5] Creating IAM Role...${NC}"

cat > /tmp/trust-policy.json << 'POLICY'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
POLICY

aws iam create-role \
    --role-name ${ROLE_NAME} \
    --assume-role-policy-document file:///tmp/trust-policy.json 2>/dev/null || echo "Role already exists"

aws iam attach-role-policy \
    --role-name ${ROLE_NAME} \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null

cat > /tmp/dynamodb-policy.json << 'POLICY'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["dynamodb:*"],
    "Resource": "arn:aws:dynamodb:*:*:table/ai-task-assistant-tasks*"
  }]
}
POLICY

aws iam put-role-policy \
    --role-name ${ROLE_NAME} \
    --policy-name DynamoDBAccess \
    --policy-document file:///tmp/dynamodb-policy.json 2>/dev/null

ROLE_ARN=$(aws iam get-role --role-name ${ROLE_NAME} --query 'Role.Arn' --output text)
echo -e "${GREEN}✅ IAM Role: ${ROLE_ARN}${NC}"

echo -e "${YELLOW}Waiting 10s for IAM propagation...${NC}"
sleep 10

# 3. Package Lambda Functions
echo -e "\n${BLUE}[3/5] Packaging Lambda Functions...${NC}"

# Create deployment directory
mkdir -p ${PROJECT_DIR}/deployment_packages

# Task Handler
echo -e "${BLUE}  Packaging task handler...${NC}"
cd ${PROJECT_DIR}/backend/lambda_functions
zip -q task_handler.zip task_handler.py
mv task_handler.zip ${PROJECT_DIR}/deployment_packages/

# Chat Handler
echo -e "${BLUE}  Packaging chat handler...${NC}"
zip -q ai_chat_handler.zip ai_chat_handler.py
mv ai_chat_handler.zip ${PROJECT_DIR}/deployment_packages/

cd ${PROJECT_DIR}

echo -e "${GREEN}✅ Packages created${NC}"
ls -lh deployment_packages/

# 4. Deploy Lambda Functions
echo -e "\n${BLUE}[4/5] Deploying Lambda Functions...${NC}"

echo -e "${BLUE}  Deploying task handler...${NC}"
aws lambda create-function \
    --function-name ai-task-assistant-task-handler \
    --runtime python3.11 \
    --role ${ROLE_ARN} \
    --handler task_handler.lambda_handler \
    --zip-file fileb://deployment_packages/task_handler.zip \
    --timeout 30 \
    --memory-size 256 \
    --region ${REGION} 2>/dev/null && echo "  ✓ Task handler created" || \
aws lambda update-function-code \
    --function-name ai-task-assistant-task-handler \
    --zip-file fileb://deployment_packages/task_handler.zip \
    --region ${REGION} > /dev/null && echo "  ✓ Task handler updated"

echo -e "${BLUE}  Deploying chat handler...${NC}"
aws lambda create-function \
    --function-name ai-task-assistant-chat-handler \
    --runtime python3.11 \
    --role ${ROLE_ARN} \
    --handler ai_chat_handler.lambda_handler \
    --zip-file fileb://deployment_packages/ai_chat_handler.zip \
    --timeout 30 \
    --memory-size 512 \
    --region ${REGION} 2>/dev/null && echo "  ✓ Chat handler created" || \
aws lambda update-function-code \
    --function-name ai-task-assistant-chat-handler \
    --zip-file fileb://deployment_packages/ai_chat_handler.zip \
    --region ${REGION} > /dev/null && echo "  ✓ Chat handler updated"

echo -e "${GREEN}✅ Lambda functions deployed${NC}"

# 5. Test
echo -e "\n${BLUE}[5/5] Testing Deployment...${NC}"

aws lambda invoke \
    --function-name ai-task-assistant-chat-handler \
    --cli-binary-format raw-in-base64-out \
    --payload '{"httpMethod":"POST","body":"{\"message\":\"test\"}"}' \
    --region ${REGION} \
    /tmp/response.json > /dev/null 2>&1

if [ -f /tmp/response.json ]; then
    echo -e "${BLUE}Test Response:${NC}"
    cat /tmp/response.json | python3 -m json.tool 2>/dev/null || cat /tmp/response.json
else
    echo -e "${YELLOW}⚠️  Test response file not found${NC}"
fi

echo -e "\n${GREEN}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║            🎉 Deployment Complete! 🎉                  ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}Lambda Functions Created:${NC}"
aws lambda list-functions \
    --query 'Functions[?starts_with(FunctionName, `ai-task-assistant`)].{Name:FunctionName,Runtime:Runtime,Status:State}' \
    --output table \
    --region ${REGION}

echo -e "\n${BLUE}DynamoDB Table:${NC}"
aws dynamodb describe-table \
    --table-name ${TABLE_NAME} \
    --query 'Table.{Name:TableName,Status:TableStatus,Items:ItemCount}' \
    --output table \
    --region ${REGION}