"""
Local testing script for Lambda functions
Run: python test_locally.py
"""

import json
from task_handler import lambda_handler as task_handler
from ai_chat_handler import lambda_handler as chat_handler


def test_create_task():
    """Test task creation"""
    event = {
        'httpMethod': 'POST',
        'body': json.dumps({
            'title': 'Test Task from Lambda',
            'description': 'Testing local Lambda execution',
            'priority': 'high',
            'status': 'pending'
        })
    }
    
    print("Testing CREATE task...")
    # Note: This will fail without DynamoDB setup, but shows structure
    # response = task_handler(event, None)
    # print(json.dumps(response, indent=2))


def test_ai_chat():
    """Test AI chat"""
    event = {
        'httpMethod': 'POST',
        'body': json.dumps({
            'message': 'Show me a task summary',
            'context': {
                'tasks': [
                    {'title': 'Task 1', 'status': 'pending', 'priority': 'high'},
                    {'title': 'Task 2', 'status': 'completed', 'priority': 'medium'}
                ]
            }
        })
    }
    
    print("\nTesting AI Chat...")
    response = chat_handler(event, None)
    print(json.dumps(json.loads(response['body']), indent=2))


if __name__ == '__main__':
    print("=" * 60)
    print("Local Lambda Function Testing")
    print("=" * 60)
    
    # test_create_task()  # Uncomment when DynamoDB is ready
    test_ai_chat()
    
    print("\n✅ Tests completed!")
