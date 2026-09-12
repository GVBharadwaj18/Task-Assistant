#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║      Adding OpenAI API Key to Lambda                  ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

REGION="us-east-1"

# Prompt for OpenAI key
echo -e "${YELLOW}Enter your OpenAI API Key:${NC}"
echo -e "${YELLOW}(starts with sk-proj-... or sk-...)${NC}"
read -s OPENAI_KEY

if [ -z "$OPENAI_KEY" ]; then
    echo -e "\n${RED}❌ Error: API key cannot be empty${NC}"
    exit 1
fi

echo -e "\n${BLUE}Configuring Lambda environment...${NC}"

# Update chat handler with OpenAI key
aws lambda update-function-configuration \
    --function-name ai-task-assistant-chat-handler \
    --environment "Variables={OPENAI_API_KEY=${OPENAI_KEY}}" \
    --region ${REGION} > /dev/null

echo -e "${GREEN}✅ OpenAI API key added to Lambda${NC}"

# Save to local config (for reference only)
mkdir -p backend/configs
cat > backend/configs/.env.local << ENVFILE
# OpenAI API Key - DO NOT COMMIT TO GIT!
OPENAI_API_KEY=${OPENAI_KEY}
ENVFILE

echo -e "${GREEN}✅ Key saved to backend/configs/.env.local${NC}"

# Add to .gitignore
if ! grep -q ".env.local" .gitignore 2>/dev/null; then
    echo ".env.local" >> .gitignore
    echo -e "${GREEN}✅ Added .env.local to .gitignore${NC}"
fi

echo -e "\n${GREEN}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║         ✅ OpenAI API Key Configured!                 ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}⚠️  Security Note: Never commit .env.local to Git!${NC}\n"