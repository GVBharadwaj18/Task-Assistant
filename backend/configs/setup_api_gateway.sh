#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║         Setting Up API Gateway                         ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}"

REGION="us-east-1"
API_NAME="ai-task-assistant-api"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# 1. Create REST API
echo -e "\n${BLUE}[1/6] Creating REST API...${NC}"

API_ID=$(aws apigateway create-rest-api \
    --name ${API_NAME} \
    --description "API for AI Task Assistant" \
    --region ${REGION} \
    --query 'id' \
    --output text 2>/dev/null)

if [ -z "$API_ID" ]; then
    # API might already exist, try to get it
    API_ID=$(aws apigateway get-rest-apis \
        --query "items[?name=='${API_NAME}'].id" \
        --output text \
        --region ${REGION})
fi

echo -e "${GREEN}✅ API ID: ${API_ID}${NC}"

# Get root resource
ROOT_ID=$(aws apigateway get-resources \
    --rest-api-id ${API_ID} \
    --region ${REGION} \
    --query 'items[?path==`/`].id' \
    --output text)

echo -e "${GREEN}✅ Root Resource ID: ${ROOT_ID}${NC}"

# 2. Create /tasks resource
echo -e "\n${BLUE}[2/6] Creating /tasks endpoint...${NC}"

TASKS_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id ${API_ID} \
    --parent-id ${ROOT_ID} \
    --path-part tasks \
    --region ${REGION} \
    --query 'id' \
    --output text 2>/dev/null || \
aws apigateway get-resources \
    --rest-api-id ${API_ID} \
    --region ${REGION} \
    --query "items[?pathPart=='tasks'].id" \
    --output text)

echo -e "${GREEN}✅ Tasks Resource ID: ${TASKS_RESOURCE_ID}${NC}"

# 3. Create POST method for /tasks
echo -e "\n${BLUE}[3/6] Setting up POST /tasks...${NC}"

aws apigateway put-method \
    --rest-api-id ${API_ID} \
    --resource-id ${TASKS_RESOURCE_ID} \
    --http-method POST \
    --authorization-type NONE \
    --region ${REGION} 2>/dev/null

aws apigateway put-integration \
    --rest-api-id ${API_ID} \
    --resource-id ${TASKS_RESOURCE_ID} \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:ai-task-assistant-task-handler/invocations" \
    --region ${REGION} 2>/dev/null

echo -e "${GREEN}✅ POST /tasks configured${NC}"

# 4. Create GET method for /tasks
echo -e "\n${BLUE}[4/6] Setting up GET /tasks...${NC}"

aws apigateway put-method \
    --rest-api-id ${API_ID} \
    --resource-id ${TASKS_RESOURCE_ID} \
    --http-method GET \
    --authorization-type NONE \
    --region ${REGION} 2>/dev/null

aws apigateway put-integration \
    --rest-api-id ${API_ID} \
    --resource-id ${TASKS_RESOURCE_ID} \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:ai-task-assistant-task-handler/invocations" \
    --region ${REGION} 2>/dev/null

echo -e "${GREEN}✅ GET /tasks configured${NC}"

# 5. Create /chat resource
echo -e "\n${BLUE}[5/6] Creating /chat endpoint...${NC}"

CHAT_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id ${API_ID} \
    --parent-id ${ROOT_ID} \
    --path-part chat \
    --region ${REGION} \
    --query 'id' \
    --output text 2>/dev/null || \
aws apigateway get-resources \
    --rest-api-id ${API_ID} \
    --region ${REGION} \
    --query "items[?pathPart=='chat'].id" \
    --output text)

aws apigateway put-method \
    --rest-api-id ${API_ID} \
    --resource-id ${CHAT_RESOURCE_ID} \
    --http-method POST \
    --authorization-type NONE \
    --region ${REGION} 2>/dev/null

aws apigateway put-integration \
    --rest-api-id ${API_ID} \
    --resource-id ${CHAT_RESOURCE_ID} \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:ai-task-assistant-chat-handler/invocations" \
    --region ${REGION} 2>/dev/null

echo -e "${GREEN}✅ POST /chat configured${NC}"

# 6. Add Lambda permissions
echo -e "\n${BLUE}[6/6] Adding Lambda permissions...${NC}"

aws lambda add-permission \
    --function-name ai-task-assistant-task-handler \
    --statement-id apigateway-tasks \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*/tasks" \
    --region ${REGION} 2>/dev/null || echo "  Permission already exists"

aws lambda add-permission \
    --function-name ai-task-assistant-chat-handler \
    --statement-id apigateway-chat \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*/chat" \
    --region ${REGION} 2>/dev/null || echo "  Permission already exists"

echo -e "${GREEN}✅ Lambda permissions configured${NC}"

# Deploy API
echo -e "\n${BLUE}Deploying API to 'prod' stage...${NC}"

aws apigateway create-deployment \
    --rest-api-id ${API_ID} \
    --stage-name prod \
    --region ${REGION} > /dev/null

API_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod"

echo -e "\n${GREEN}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║          🎉 API Gateway Setup Complete! 🎉            ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}Your API Endpoints:${NC}"
echo -e "${GREEN}Base URL:${NC} ${API_URL}"
echo -e "${GREEN}Tasks:${NC}   ${API_URL}/tasks"
echo -e "${GREEN}Chat:${NC}    ${API_URL}/chat"

echo -e "\n${YELLOW}Save these URLs - you'll need them for frontend integration!${NC}"

# Save to config file
cat > backend/configs/api-endpoints.env << ENVFILE
API_BASE_URL=${API_URL}
API_TASKS_ENDPOINT=${API_URL}/tasks
API_CHAT_ENDPOINT=${API_URL}/chat
ENVFILE

echo -e "\n${GREEN}✅ Endpoints saved to: backend/configs/api-endpoints.env${NC}"
