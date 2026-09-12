// API Configuration and Helper Functions
const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL ||
  "https://zfj1i8ugql.execute-api.us-east-1.amazonaws.com/prod";

export interface Task {
  id: string;
  title: string;
  description: string;
  priority: "low" | "medium" | "high";
  status: "pending" | "in-progress" | "completed";
  createdAt: string;
  updatedAt: string;
  aiSuggestion?: string;
}

export interface ChatResponse {
  response: string;
  timestamp: string;
}

// Task API Functions
export const taskAPI = {
  // Get all tasks
  getTasks: async (): Promise<Task[]> => {
    const response = await fetch(`${API_BASE_URL}/tasks`);
    if (!response.ok) throw new Error("Failed to fetch tasks");
    const data = await response.json();
    return data.tasks || [];
  },

  // Create a new task
  createTask: async (
    task: Omit<Task, "id" | "createdAt" | "updatedAt">
  ): Promise<Task> => {
    const response = await fetch(`${API_BASE_URL}/tasks`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(task),
    });
    if (!response.ok) throw new Error("Failed to create task");
    return response.json();
  },

  // Update a task
  updateTask: async (taskId: string, updates: Partial<Task>): Promise<Task> => {
    const response = await fetch(`${API_BASE_URL}/tasks/${taskId}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(updates),
    });
    if (!response.ok) throw new Error("Failed to update task");
    return response.json();
  },

  // Delete a task
  deleteTask: async (taskId: string): Promise<void> => {
    const response = await fetch(`${API_BASE_URL}/tasks/${taskId}`, {
      method: "DELETE",
    });
    if (!response.ok) throw new Error("Failed to delete task");
  },
};

// Chat API Functions
export const chatAPI = {
  sendMessage: async (
    message: string,
    tasks: Task[] = []
  ): Promise<ChatResponse> => {
    const response = await fetch(`${API_BASE_URL}/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message, context: { tasks } }),
    });
    if (!response.ok) throw new Error("Failed to send chat message");
    return response.json();
  },
};
