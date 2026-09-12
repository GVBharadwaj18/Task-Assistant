"""
AWS Lambda Function: AI Chat Handler
Direct OpenAI API integration without SDK dependencies
"""

import json
import os
import urllib.request
import urllib.error
from datetime import datetime
from typing import Dict, Any

# Get OpenAI key from environment
OPENAI_API_KEY = os.environ.get('OPENAI_API_KEY', '')


def cors_headers() -> Dict[str, str]:
    """CORS headers for API responses"""
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'POST,OPTIONS'
    }


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Main Lambda handler for AI chat operations"""
    
    print(f"Event: {json.dumps(event)}")
    
    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': ''
        }
    
    try:
        body = json.loads(event.get('body', '{}'))
        user_message = body.get('message', '')
        context_data = body.get('context', {})
        
        if not user_message:
            return {
                'statusCode': 400,
                'headers': cors_headers(),
                'body': json.dumps({'error': 'Message is required'})
            }
        
        # Get AI response
        if OPENAI_API_KEY and OPENAI_API_KEY.startswith('sk-'):
            ai_response = get_openai_response(user_message, context_data)
        else:
            ai_response = "⚠️ OpenAI API key not configured.\n\n" + get_fallback_response(user_message, context_data)
        
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({
                'response': ai_response,
                'timestamp': datetime.utcnow().isoformat()
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'error': str(e)})
        }


def get_openai_response(user_message: str, context: Dict[str, Any]) -> str:
    """Get AI response using direct OpenAI HTTP API"""
    
    try:
        tasks = context.get('tasks', [])
        
        # Build system prompt
        system_prompt = """You are an intelligent task management assistant. 

Your capabilities:
- Analyze task lists and provide insights
- Suggest priorities and time management strategies
- Break down complex tasks into actionable steps
- Provide productivity tips

Communication style:
- Be concise (2-3 short paragraphs max)
- Use bullet points for lists
- Add relevant emojis sparingly
- Be encouraging and supportive"""
        
        # Add task context
        task_context = ""
        if tasks:
            pending = [t for t in tasks if t.get('status') == 'pending']
            completed = [t for t in tasks if t.get('status') == 'completed']
            high_priority = [t for t in tasks if t.get('priority') == 'high' and t.get('status') != 'completed']
            
            task_context = f"""
Current Tasks: {len(tasks)} total | {len(pending)} pending | {len(completed)} completed
High Priority: {len(high_priority)}

Top Tasks:
{chr(10).join([f"• {t.get('title')}" for t in (high_priority or tasks)[:3]])}
"""
        
        # Prepare request to OpenAI
        url = "https://api.openai.com/v1/chat/completions"
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {OPENAI_API_KEY}"
        }
        
        data = {
            "model": "gpt-4o-mini",
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "system", "content": task_context},
                {"role": "user", "content": user_message}
            ],
            "max_tokens": 400,
            "temperature": 0.7
        }
        
        # Make HTTP request
        req = urllib.request.Request(
            url,
            data=json.dumps(data).encode('utf-8'),
            headers=headers,
            method='POST'
        )
        
        with urllib.request.urlopen(req, timeout=30) as response:
            result = json.loads(response.read().decode('utf-8'))
            return result['choices'][0]['message']['content']
        
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8')
        print(f"OpenAI HTTP Error {e.code}: {error_body}")
        
        if e.code == 401:
            return get_fallback_response(user_message, context)
        else:
            return get_fallback_response(user_message, context)
    
    except Exception as e:
        print(f"OpenAI Error: {str(e)}")
        return f"⚠️ Error connecting to OpenAI: {str(e)}\n\n" + get_fallback_response(user_message, context)


def get_fallback_response(user_message: str, context: Dict[str, Any]) -> str:
    """Fallback response when OpenAI is not available"""
    
    tasks = context.get('tasks', [])
    message_lower = user_message.lower()
    
    if 'summary' in message_lower or 'status' in message_lower:
        pending = len([t for t in tasks if t.get('status') == 'pending'])
        completed = len([t for t in tasks if t.get('status') == 'completed'])
        high_priority = len([t for t in tasks if t.get('priority') == 'high' and t.get('status') != 'completed'])
        
        return f"""📊 **Task Summary**

• Total: {len(tasks)} tasks
• Pending: {pending}
• Completed: {completed}
• High priority: {high_priority}

{"🎯 Focus on your " + str(high_priority) + " high-priority tasks first!" if high_priority > 0 else "✨ Great job! No high-priority tasks pending."}"""
    
    elif 'model' in message_lower:
        return "I'm powered by **GPT-4o-mini** running on AWS Lambda! 🧠 I can help you manage tasks, prioritize work, and boost productivity."
    
    elif 'priority' in message_lower or 'focus' in message_lower:
        high_priority_tasks = [t for t in tasks if t.get('priority') == 'high' and t.get('status') != 'completed']
        
        if high_priority_tasks:
            task_list = "\n".join([f"• {t.get('title')}" for t in high_priority_tasks[:5]])
            return f"""🎯 **High Priority Tasks** ({len(high_priority_tasks)} total)

{task_list}

Tackle these one at a time!"""
        else:
            return "✨ No high-priority tasks pending. Great work!"
    
    return f"""I understand: "{user_message}"

Try asking:
• "Show my task summary"
• "What should I focus on?"
• "Help me prioritize"

Your tasks are stored in AWS DynamoDB! 🚀"""



