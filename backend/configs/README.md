# Configuration Scripts

## Deployment Scripts

### Initial Setup

- `deploy_all.sh` - Initial AWS infrastructure setup
- `setup_api_gateway.sh` - API Gateway configuration
- `add_task_id_endpoint.sh` - Add CRUD endpoints
- `enable_cors.sh` - Enable CORS

### Lambda Management

- `add_openai_key.sh` - Add/update OpenAI API key
- `quick_deploy.sh` - Quick Lambda code deployment

## Environment Variables

### Lambda Functions

- `OPENAI_API_KEY` - OpenAI API key (set via add_openai_key.sh)

## API Endpoints

Base URL: `https://your-api-id.execute-api.us-east-1.amazonaws.com/prod`

- `GET /tasks` - List all tasks
- `POST /tasks` - Create task
- `GET /tasks/{id}` - Get single task
- `PUT /tasks/{id}` - Update task
- `DELETE /tasks/{id}` - Delete task
- `POST /chat` - AI chat

## AWS Resources

- **DynamoDB Table**: `ai-task-assistant-tasks`
- **Lambda Functions**:
  - `ai-task-assistant-task-handler`
  - `ai-task-assistant-chat-handler`
- **IAM Role**: `TaskAssistantLambdaRole`
- **API Gateway**: `ai-task-assistant-api`
