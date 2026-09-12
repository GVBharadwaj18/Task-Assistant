#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Adding /tasks/{id} endpoint...${NC}\n"

REGION="us-east-1"
API_ID="${1:-your_api_id_here}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Get tasks resource ID
TASKS_RESOURCE_ID=$(aws apigateway get-resources \
    --rest-api-id ${API_ID} \
    --region ${REGION} \
    --query "items[?pathPart=='tasks'].id" \
    --output text)

echo -e "${GREEN}Tasks Resource ID: ${TASKS_RESOURCE_ID}${NC}"

# Create {id} resource under /tasks
echo -e "\n${BLUE}[1/4] Creating /tasks/{id} resource...${NC}"

TASK_ID_RESOURCE=$(aws apigateway create-resource \
    --rest-api-id ${API_ID} \
    --parent-id ${TASKS_RESOURCE_ID} \
    --path-part '{id}' \
    --region ${REGION} \
    --query 'id' \
    --output text 2>/dev/null || \
aws apigateway get-resources \
    --rest-api-id ${API_ID} \
    --region ${REGION} \
    --query "items[?pathPart=='{id}'].id" \
    --output text)

echo -e "${GREEN}✅ Task ID Resource: ${TASK_ID_RESOURCE}${NC}"

# Add GET method for /tasks/{id}
echo -e "\n${BLUE}[2/4] Adding GET /tasks/{id}...${NC}"

aws apigateway put-method \
    --rest-api-id ${API_ID} \
    --resource-id ${TASK_ID_RESOURCE} \
    --http-method GET \
    --authorization-type NONE \
    --request-parameters '{"method.request.path.id": true}' \
    --region ${REGION} 2>/dev/null

aws apigateway put-integration \
    --rest-api-id ${API_ID} \
    --resource-id ${TASK_ID_RESOURCE} \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:ai-task-assistant-task-handler/invocations" \
    --region ${REGION} 2>/dev/null

echo -e "${GREEN}✅ GET /tasks/{id} configured${NC}"

# Add PUT method for /tasks/{id}
echo -e "\n${BLUE}[3/4] Adding PUT /tasks/{id}...${NC}"

aws apigateway put-method \
    --rest-api-id ${API_ID} \
    --resource-id ${TASK_ID_RESOURCE} \
    --http-method PUT \
    --authorization-type NONE \
    --request-parameters '{"method.request.path.id": true}' \
    --region ${REGION} 2>/dev/null

aws apigateway put-integration \
    --rest-api-id ${API_ID} \
    --resource-id ${TASK_ID_RESOURCE} \
    --http-method PUT \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:ai-task-assistant-task-handler/invocations" \
    --region ${REGION} 2>/dev/null

echo -e "${GREEN}✅ PUT /tasks/{id} configured${NC}"

# Add DELETE method for /tasks/{id}
echo -e "\n${BLUE}[4/4] Adding DELETE /tasks/{id}...${NC}"

aws apigateway put-method \
    --rest-api-id ${API_ID} \
    --resource-id ${TASK_ID_RESOURCE} \
    --http-method DELETE \
    --authorization-type NONE \
    --request-parameters '{"method.request.path.id": true}' \
    --region ${REGION} 2>/dev/null

aws apigateway put-integration \
    --rest-api-id ${API_ID} \
    --resource-id ${TASK_ID_RESOURCE} \
    --http-method DELETE \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:ai-task-assistant-task-handler/invocations" \
    --region ${REGION} 2>/dev/null

echo -e "${GREEN}✅ DELETE /tasks/{id} configured${NC}"

# Add CORS for /tasks/{id}
echo -e "\n${BLUE}Enabling CORS for /tasks/{id}...${NC}"

aws apigateway put-method \
    --rest-api-id ${API_ID} \
    --resource-id ${TASK_ID_RESOURCE} \
    --http-method OPTIONS \
    --authorization-type NONE \
    --region ${REGION} 2>/dev/null

aws apigateway put-method-response \
    --rest-api-id ${API_ID} \
    --resource-id ${TASK_ID_RESOURCE} \
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
    --resource-id ${TASK_ID_RESOURCE} \
    --http-method OPTIONS \
    --type MOCK \
    --request-templates '{"application/json": "{\"statusCode\": 200}"}' \
    --region ${REGION} 2>/dev/null

aws apigateway put-integration-response \
    --rest-api-id ${API_ID} \
    --resource-id ${TASK_ID_RESOURCE} \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{
        "method.response.header.Access-Control-Allow-Headers": "'\''Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'\''",
        "method.response.header.Access-Control-Allow-Methods": "'\''GET,PUT,DELETE,OPTIONS'\''",
        "method.response.header.Access-Control-Allow-Origin": "'\''*'\''"
    }' \
    --region ${REGION} 2>/dev/null

echo -e "${GREEN}✅ CORS enabled for /tasks/{id}${NC}"

# Update Lambda permissions
echo -e "\n${BLUE}Updating Lambda permissions...${NC}"

aws lambda add-permission \
    --function-name ai-task-assistant-task-handler \
    --statement-id apigateway-task-id \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*/tasks/*" \
    --region ${REGION} 2>/dev/null || echo "  Permission already exists"

# Deploy changes
echo -e "\n${BLUE}Deploying to production...${NC}"
aws apigateway create-deployment \
    --rest-api-id ${API_ID} \
    --stage-name prod \
    --region ${REGION} > /dev/null

echo -e "\n${GREEN}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║      ✅ Task ID Endpoint Added Successfully!          ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}Available endpoints:${NC}"
echo "• GET    /tasks       - List all tasks"
echo "• POST   /tasks       - Create task"
echo "• GET    /tasks/{id}  - Get single task"
echo "• PUT    /tasks/{id}  - Update task"
echo "• DELETE /tasks/{id}  - Delete task"
echo "• POST   /chat        - AI chat"
echo ""
