#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Quick Deploy - AI Chat Handler${NC}\n"

cd ~/Documents/Serverless_AI-Powered_Task_Assistant

# Package
mkdir -p /tmp/lambda_simple
cp backend/lambda_functions/ai_chat_handler.py /tmp/lambda_simple/
cd /tmp/lambda_simple
zip -r ai_chat_handler_simple.zip . -q

# Move package
mkdir -p ~/Documents/Serverless_AI-Powered_Task_Assistant/deployment_packages
mv ai_chat_handler_simple.zip ~/Documents/Serverless_AI-Powered_Task_Assistant/deployment_packages/

cd ~/Documents/Serverless_AI-Powered_Task_Assistant

# Deploy
aws lambda update-function-code \
    --function-name ai-task-assistant-chat-handler \
    --zip-file fileb://deployment_packages/ai_chat_handler_simple.zip \
    --region us-east-1

echo -e "\n${GREEN}✅ Deployed! Wait 10 seconds then test at http://localhost:3000${NC}\n"

# Cleanup
rm -rf /tmp/lambda_simple
