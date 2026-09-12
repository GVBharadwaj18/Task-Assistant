#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Enabling CORS on API Gateway...${NC}\n"

REGION="us-east-1"
API_ID="${1:-your_api_id_here}"

# Get resources
ROOT_ID=$(aws apigateway get-resources \
    --rest-api-id ${API_ID} \
    --region ${REGION} \
    --query 'items[?path==`/`].id' \
    --output text)

TASKS_RESOURCE_ID=$(aws apigateway get-resources \
    --rest-api-id ${API_ID} \
    --region ${REGION} \
    --query "items[?pathPart=='tasks'].id" \
    --output text)

CHAT_RESOURCE_ID=$(aws apigateway get-resources \
    --rest-api-id ${API_ID} \
    --region ${REGION} \
    --query "items[?pathPart=='chat'].id" \
    --output text)

echo -e "${GREEN}Resource IDs:${NC}"
echo "Root: $ROOT_ID"
echo "Tasks: $TASKS_RESOURCE_ID"
echo "Chat: $CHAT_RESOURCE_ID"

# Enable CORS for /tasks
echo -e "\n${BLUE}[1/2] Enabling CORS for /tasks...${NC}"

aws apigateway put-method \
    --rest-api-id ${API_ID} \
    --resource-id ${TASKS_RESOURCE_ID} \
    --http-method OPTIONS \
    --authorization-type NONE \
    --region ${REGION} 2>/dev/null

aws apigateway put-method-response \
    --rest-api-id ${API_ID} \
    --resource-id ${TASKS_RESOURCE_ID} \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{
        "method.response.header.Access-Control-Allow-Headers": true,
        "method.response.header.Access-Control-Allow-Methods": true,
        "method.response.header.Access-Control-Allow-Origin": true
    }' \
    --region ${REGION} 2>/dev/null

aws apigateway put-integration \
    --rest-api-id ${API_ID} \
    --resource-id ${TASKS_RESOURCE_ID} \
    --http-method OPTIONS \
    --type MOCK \
    --request-templates '{"application/json": "{\"statusCode\": 200}"}' \
    --region ${REGION} 2>/dev/null

aws apigateway put-integration-response \
    --rest-api-id ${API_ID} \
    --resource-id ${TASKS_RESOURCE_ID} \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{
        "method.response.header.Access-Control-Allow-Headers": "'\''Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'\''",
        "method.response.header.Access-Control-Allow-Methods": "'\''GET,POST,PUT,DELETE,OPTIONS'\''",
        "method.response.header.Access-Control-Allow-Origin": "'\''*'\''"
    }' \
    --region ${REGION} 2>/dev/null

echo -e "${GREEN}✅ CORS enabled for /tasks${NC}"

# Enable CORS for /chat
echo -e "\n${BLUE}[2/2] Enabling CORS for /chat...${NC}"

aws apigateway put-method \
    --rest-api-id ${API_ID} \
    --resource-id ${CHAT_RESOURCE_ID} \
    --http-method OPTIONS \
    --authorization-type NONE \
    --region ${REGION} 2>/dev/null

aws apigateway put-method-response \
    --rest-api-id ${API_ID} \
    --resource-id ${CHAT_RESOURCE_ID} \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{
        "method.response.header.Access-Control-Allow-Headers": true,
        "method.response.header.Access-Control-Allow-Methods": true,
        "method.response.header.Access-Control-Allow-Origin": true
    }' \
    --region ${REGION} 2>/dev/null

aws apigateway put-integration \
    --rest-api-id ${API_ID} \
    --resource-id ${CHAT_RESOURCE_ID} \
    --http-method OPTIONS \
    --type MOCK \
    --request-templates '{"application/json": "{\"statusCode\": 200}"}' \
    --region ${REGION} 2>/dev/null

aws apigateway put-integration-response \
    --rest-api-id ${API_ID} \
    --resource-id ${CHAT_RESOURCE_ID} \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{
        "method.response.header.Access-Control-Allow-Headers": "'\''Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'\''",
        "method.response.header.Access-Control-Allow-Methods": "'\''POST,OPTIONS'\''",
        "method.response.header.Access-Control-Allow-Origin": "'\''*'\''"
    }' \
    --region ${REGION} 2>/dev/null

echo -e "${GREEN}✅ CORS enabled for /chat${NC}"

# Deploy changes
echo -e "\n${BLUE}Deploying changes...${NC}"
aws apigateway create-deployment \
    --rest-api-id ${API_ID} \
    --stage-name prod \
    --region ${REGION} > /dev/null

echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ CORS Enabled Successfully!        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo -e "\n${BLUE}Test your app now at http://localhost:3000${NC}\n"
