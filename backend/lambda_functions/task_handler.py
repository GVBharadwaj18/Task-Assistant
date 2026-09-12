"""
AWS Lambda Function: Task Handler
Handles CRUD operations for tasks
"""

import json
import uuid
import boto3
from datetime import datetime
from decimal import Decimal
from typing import Dict, Any, List

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
TASKS_TABLE = dynamodb.Table('ai-task-assistant-tasks')


class DecimalEncoder(json.JSONEncoder):
    """Helper class to convert Decimal to float for JSON serialization"""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)


def cors_headers() -> Dict[str, str]:
    """CORS headers for API responses"""
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    }


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Main Lambda handler for task operations"""
    
    print(f"Event: {json.dumps(event)}")
    
    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': ''
        }
    
    http_method = event.get('httpMethod', '')
    path_parameters = event.get('pathParameters') or {}
    task_id = path_parameters.get('id')
    
    try:
        if http_method == 'GET' and task_id:
            response = get_task(task_id)
        elif http_method == 'GET':
            response = list_tasks(event)
        elif http_method == 'POST':
            response = create_task(event)
        elif http_method == 'PUT' and task_id:
            response = update_task(task_id, event)
        elif http_method == 'DELETE' and task_id:
            response = delete_task(task_id)
        else:
            response = {
                'statusCode': 400,
                'body': json.dumps({'error': 'Invalid request method or path'})
            }
        
        response['headers'] = cors_headers()
        return response
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'error': str(e)})
        }


def create_task(event: Dict[str, Any]) -> Dict[str, Any]:
    """Create a new task"""
    try:
        body = json.loads(event.get('body', '{}'))
        
        if not body.get('title'):
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Title is required'})
            }
        
        task_id = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat()
        
        task = {
            'id': task_id,
            'title': body['title'],
            'description': body.get('description', ''),
            'priority': body.get('priority', 'medium'),
            'status': body.get('status', 'pending'),
            'createdAt': timestamp,
            'updatedAt': timestamp,
            'aiSuggestion': body.get('aiSuggestion', '')
        }
        
        TASKS_TABLE.put_item(Item=task)
        
        return {
            'statusCode': 201,
            'body': json.dumps(task, cls=DecimalEncoder)
        }
        
    except Exception as e:
        print(f"Create task error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': f'Failed to create task: {str(e)}'})
        }


def list_tasks(event: Dict[str, Any]) -> Dict[str, Any]:
    """List all tasks"""
    try:
        query_params = event.get('queryStringParameters') or {}
        status_filter = query_params.get('status')
        
        response = TASKS_TABLE.scan()
        tasks = response.get('Items', [])
        
        if status_filter:
            tasks = [t for t in tasks if t.get('status') == status_filter]
        
        tasks.sort(key=lambda x: x.get('createdAt', ''), reverse=True)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'tasks': tasks,
                'count': len(tasks)
            }, cls=DecimalEncoder)
        }
        
    except Exception as e:
        print(f"List tasks error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': f'Failed to list tasks: {str(e)}'})
        }


def get_task(task_id: str) -> Dict[str, Any]:
    """Get a single task by ID"""
    try:
        response = TASKS_TABLE.get_item(Key={'id': task_id})
        
        if 'Item' not in response:
            return {
                'statusCode': 404,
                'body': json.dumps({'error': 'Task not found'})
            }
        
        return {
            'statusCode': 200,
            'body': json.dumps(response['Item'], cls=DecimalEncoder)
        }
        
    except Exception as e:
        print(f"Get task error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': f'Failed to get task: {str(e)}'})
        }


def update_task(task_id: str, event: Dict[str, Any]) -> Dict[str, Any]:
    """Update an existing task"""
    try:
        body = json.loads(event.get('body', '{}'))
        
        update_expr = "SET updatedAt = :updated"
        expr_values = {':updated': datetime.utcnow().isoformat()}
        expr_names = None
        
        if 'title' in body:
            update_expr += ", title = :title"
            expr_values[':title'] = body['title']
        
        if 'description' in body:
            update_expr += ", description = :desc"
            expr_values[':desc'] = body['description']
        
        if 'priority' in body:
            update_expr += ", priority = :priority"
            expr_values[':priority'] = body['priority']
        
        if 'status' in body:
            update_expr += ", #status = :status"
            expr_values[':status'] = body['status']
            expr_names = {'#status': 'status'}
        
        if 'aiSuggestion' in body:
            update_expr += ", aiSuggestion = :suggestion"
            expr_values[':suggestion'] = body['aiSuggestion']
        
        update_params = {
            'Key': {'id': task_id},
            'UpdateExpression': update_expr,
            'ExpressionAttributeValues': expr_values,
            'ReturnValues': 'ALL_NEW'
        }
        
        if expr_names:
            update_params['ExpressionAttributeNames'] = expr_names
        
        response = TASKS_TABLE.update_item(**update_params)
        
        return {
            'statusCode': 200,
            'body': json.dumps(response['Attributes'], cls=DecimalEncoder)
        }
        
    except Exception as e:
        print(f"Update task error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': f'Failed to update task: {str(e)}'})
        }


def delete_task(task_id: str) -> Dict[str, Any]:
    """Delete a task"""
    try:
        TASKS_TABLE.delete_item(Key={'id': task_id})
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Task deleted successfully',
                'id': task_id
            })
        }
        
    except Exception as e:
        print(f"Delete task error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': f'Failed to delete task: {str(e)}'})
        }