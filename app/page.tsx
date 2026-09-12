"use client";

import { useState, useEffect } from "react";
import {
  CheckCircle2,
  Circle,
  Trash2,
  Plus,
  Sparkles,
  Clock,
  Calendar,
  Zap,
  Bot,
  Send,
  RefreshCw,
} from "lucide-react";
import { format } from "date-fns";
import { taskAPI, chatAPI, Task } from "./lib/api";

interface Message {
  id: string;
  role: "user" | "assistant";
  content: string;
  timestamp: Date;
}

export default function TaskAssistant() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [messages, setMessages] = useState<Message[]>([
    {
      id: "1",
      role: "assistant",
      content: "Welcome to AI Task Assistant! 🚀 How can I help optimize your workflow today?",
      timestamp: new Date(),
    },
  ]);

  const [newTaskTitle, setNewTaskTitle] = useState("");
  const [newTaskDescription, setNewTaskDescription] = useState("");
  const [newTaskPriority, setNewTaskPriority] = useState<"low" | "medium" | "high">("medium");
  const [chatInput, setChatInput] = useState("");
  const [filterStatus, setFilterStatus] = useState<"all" | "pending" | "completed">("all");
  const [isProcessing, setIsProcessing] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadTasks();
  }, []);

  const loadTasks = async () => {
    try {
      setIsLoading(true);
      const fetchedTasks = await taskAPI.getTasks();
      setTasks(fetchedTasks);
    } catch (error) {
      console.error("Failed to load tasks:", error);
      addMessage("assistant", "⚠️ Connection error. Syncing with AWS Cloud...");
    } finally {
      setIsLoading(false);
    }
  };

  const handleCreateTask = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTaskTitle.trim()) return;

    try {
      setIsSaving(true);
      const newTask = await taskAPI.createTask({
        title: newTaskTitle.trim(),
        description: newTaskDescription.trim(),
        priority: newTaskPriority,
        status: "pending",
      });

      setTasks((prev) => [newTask, ...prev]);
      setNewTaskTitle("");
      setNewTaskDescription("");
      setNewTaskPriority("medium");
    } catch (error) {
      console.error("Failed to create task:", error);
      addMessage("assistant", "❌ Failed to save task to AWS. Please try again.");
    } finally {
      setIsSaving(false);
    }
  };

  const toggleTaskStatus = async (taskId: string) => {
    const task = tasks.find((t) => t.id === taskId);
    if (!task) return;

    const newStatus = task.status === "completed" ? "pending" : "completed";

    try {
      setTasks((prev) =>
        prev.map((t) => (t.id === taskId ? { ...t, status: newStatus } : t))
      );
      await taskAPI.updateTask(taskId, { status: newStatus });
    } catch (error) {
      console.error("Failed to update task:", error);
      setTasks((prev) =>
        prev.map((t) => (t.id === taskId ? { ...t, status: task.status } : t))
      );
      addMessage("assistant", "❌ Failed to update task status.");
    }
  };

  const deleteTask = async (taskId: string) => {
    try {
      setTasks((prev) => prev.filter((t) => t.id !== taskId));
      await taskAPI.deleteTask(taskId);
    } catch (error) {
      console.error("Failed to delete task:", error);
      addMessage("assistant", "❌ Failed to delete task.");
    }
  };

  const addMessage = (role: "user" | "assistant", content: string) => {
    setMessages((prev) => [
      ...prev,
      {
        id: Date.now().toString() + Math.random().toString(36).substring(2, 5),
        role,
        content,
        timestamp: new Date(),
      },
    ]);
  };

  const submitChat = async (promptText: string) => {
    if (!promptText.trim()) return;

    addMessage("user", promptText);
    setChatInput("");
    setIsProcessing(true);

    try {
      const response = await chatAPI.sendMessage(promptText, tasks);
      addMessage("assistant", response.response);
    } catch (error) {
      console.error("Chat error:", error);
      addMessage("assistant", "❌ Error connecting to AI Copilot.");
    } finally {
      setIsProcessing(false);
    }
  };

  const handleChatFormSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    submitChat(chatInput);
  };

  const filteredTasks = tasks.filter((task) => {
    if (filterStatus === "pending") return task.status !== "completed";
    if (filterStatus === "completed") return task.status === "completed";
    return true;
  });

  const pendingCount = tasks.filter((t) => t.status !== "completed").length;
  const completedCount = tasks.filter((t) => t.status === "completed").length;
  const highPriorityCount = tasks.filter((t) => t.priority === "high" && t.status !== "completed").length;

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 selection:bg-cyan-500 selection:text-white">
      <div className="fixed top-0 left-1/4 w-[600px] h-[300px] bg-gradient-to-r from-violet-600/20 via-indigo-600/20 to-cyan-500/20 blur-[120px] pointer-events-none rounded-full" />

      <div className="container mx-auto px-4 py-8 max-w-7xl relative z-10">
        <header className="mb-8 flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-slate-800/80 pb-6">
          <div className="flex items-center gap-3">
            <div className="p-2.5 rounded-xl bg-gradient-to-tr from-cyan-500 to-indigo-600 shadow-lg shadow-cyan-500/20">
              <Sparkles className="w-7 h-7 text-white" />
            </div>
            <div>
              <h1 className="text-3xl font-extrabold tracking-tight bg-gradient-to-r from-white via-slate-100 to-slate-400 bg-clip-text text-transparent">
                AI Task Assistant
              </h1>
              <p className="text-xs text-slate-400 font-medium">Powered by AWS Serverless & GPT-4 Architecture</p>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={loadTasks}
              className="px-3.5 py-2 rounded-lg bg-slate-900 border border-slate-800 hover:border-slate-700 text-xs font-medium text-slate-300 hover:text-white transition flex items-center gap-2 shadow-sm"
            >
              <RefreshCw className={`w-3.5 h-3.5 ${isLoading ? "animate-spin text-cyan-400" : ""}`} />
              Sync AWS Data
            </button>
          </div>
        </header>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
          <div className="glass-card rounded-xl p-4 border border-slate-800/80">
            <div className="flex items-center justify-between text-slate-400 mb-1">
              <span className="text-xs font-medium">Total Tasks</span>
              <Calendar className="w-4 h-4 text-cyan-400" />
            </div>
            <p className="text-2xl font-bold text-white">{tasks.length}</p>
          </div>

          <div className="glass-card rounded-xl p-4 border border-slate-800/80">
            <div className="flex items-center justify-between text-slate-400 mb-1">
              <span className="text-xs font-medium">Pending Tasks</span>
              <Clock className="w-4 h-4 text-amber-400" />
            </div>
            <p className="text-2xl font-bold text-amber-300">{pendingCount}</p>
          </div>

          <div className="glass-card rounded-xl p-4 border border-slate-800/80">
            <div className="flex items-center justify-between text-slate-400 mb-1">
              <span className="text-xs font-medium">Completed</span>
              <CheckCircle2 className="w-4 h-4 text-emerald-400" />
            </div>
            <p className="text-2xl font-bold text-emerald-400">{completedCount}</p>
          </div>

          <div className="glass-card rounded-xl p-4 border border-slate-800/80">
            <div className="flex items-center justify-between text-slate-400 mb-1">
              <span className="text-xs font-medium">High Priority</span>
              <Zap className="w-4 h-4 text-rose-400" />
            </div>
            <p className="text-2xl font-bold text-rose-400">{highPriorityCount}</p>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
          <div className="lg:col-span-5 space-y-6">
            <div className="glass-card rounded-2xl p-6 border border-slate-800 shadow-xl">
              <h2 className="text-lg font-semibold mb-4 text-white flex items-center gap-2">
                <Plus className="w-5 h-5 text-cyan-400" />
                Create New Task
              </h2>

              <form onSubmit={handleCreateTask} className="space-y-4">
                <div>
                  <label htmlFor="task-title-input" className="block text-xs font-medium text-slate-400 mb-1">Task Title *</label>
                  <input
                    id="task-title-input"
                    type="text"
                    required
                    value={newTaskTitle}
                    onChange={(e) => setNewTaskTitle(e.target.value)}
                    placeholder="e.g., Optimize DynamoDB Query Performance"
                    className="w-full px-4 py-2.5 bg-slate-900/90 border border-slate-800 rounded-xl focus:ring-2 focus:ring-cyan-500 focus:border-transparent text-sm text-white placeholder-slate-500 outline-none transition"
                  />
                </div>

                <div>
                  <label htmlFor="task-desc-input" className="block text-xs font-medium text-slate-400 mb-1">Description</label>
                  <textarea
                    id="task-desc-input"
                    value={newTaskDescription}
                    onChange={(e) => setNewTaskDescription(e.target.value)}
                    placeholder="Add details, links, or notes..."
                    rows={3}
                    className="w-full px-4 py-2.5 bg-slate-900/90 border border-slate-800 rounded-xl focus:ring-2 focus:ring-cyan-500 focus:border-transparent text-sm text-white placeholder-slate-500 outline-none transition resize-none"
                  />
                </div>

                <div>
                  <label className="block text-xs font-medium text-slate-400 mb-1">Priority Level</label>
                  <div className="grid grid-cols-3 gap-2">
                    {(["low", "medium", "high"] as const).map((p) => (
                      <button
                        key={p}
                        type="button"
                        onClick={() => setNewTaskPriority(p)}
                        className={`py-2 px-3 text-xs font-semibold rounded-lg capitalize border transition ${
                          newTaskPriority === p
                            ? p === "high"
                              ? "bg-rose-500/20 border-rose-500 text-rose-300"
                              : p === "medium"
                              ? "bg-amber-500/20 border-amber-500 text-amber-300"
                              : "bg-emerald-500/20 border-emerald-500 text-emerald-300"
                            : "bg-slate-900 border-slate-800 text-slate-400 hover:border-slate-700"
                        }`}
                      >
                        {p}
                      </button>
                    ))}
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={isSaving || !newTaskTitle.trim()}
                  className="w-full bg-gradient-to-r from-cyan-500 to-indigo-600 hover:from-cyan-400 hover:to-indigo-500 text-white font-medium py-2.5 px-4 rounded-xl shadow-lg shadow-cyan-500/25 transition flex items-center justify-center gap-2 text-sm mt-2 disabled:opacity-50 cursor-pointer"
                >
                  <Plus className="w-4 h-4" />
                  {isSaving ? "Saving to AWS..." : "Save Task to AWS DynamoDB"}
                </button>
              </form>
            </div>

            <div className="glass-card rounded-2xl p-5 border border-slate-800">
              <h3 className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-3 flex items-center gap-2">
                <Bot className="w-4 h-4 text-violet-400" />
                Quick AI Assistant Prompts
              </h3>

              <div className="flex flex-col gap-2">
                {[
                  "Summarize all pending tasks",
                  "What high priority task should I focus on?",
                  "Give me productivity recommendations",
                ].map((promptText, idx) => (
                  <button
                    key={idx}
                    type="button"
                    onClick={() => submitChat(promptText)}
                    className="text-left text-xs bg-slate-900/80 hover:bg-slate-800 border border-slate-800 hover:border-violet-500/40 p-2.5 rounded-lg text-slate-300 hover:text-white transition flex items-center justify-between group cursor-pointer"
                  >
                    <span>"{promptText}"</span>
                    <Sparkles className="w-3.5 h-3.5 text-violet-400 group-hover:scale-110 transition" />
                  </button>
                ))}
              </div>
            </div>
          </div>

          <div className="lg:col-span-7 space-y-6">
            <div className="glass-card rounded-2xl p-6 border border-slate-800 shadow-xl">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-6">
                <h2 className="text-lg font-semibold text-white flex items-center gap-2">
                  <Calendar className="w-5 h-5 text-indigo-400" />
                  Task Stream ({filteredTasks.length})
                </h2>

                <div className="flex items-center gap-1 bg-slate-900 p-1 rounded-xl border border-slate-800">
                  {(["all", "pending", "completed"] as const).map((s) => (
                    <button
                      key={s}
                      type="button"
                      onClick={() => setFilterStatus(s)}
                      className={`px-3 py-1 text-xs font-medium rounded-lg capitalize transition cursor-pointer ${
                        filterStatus === s
                          ? "bg-indigo-600 text-white shadow-sm"
                          : "text-slate-400 hover:text-slate-200"
                      }`}
                    >
                      {s}
                    </button>
                  ))}
                </div>
              </div>

              {isLoading ? (
                <div className="text-center py-16 text-slate-400">
                  <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-cyan-500 mx-auto"></div>
                  <p className="mt-4 text-sm">Fetching tasks from AWS DynamoDB...</p>
                </div>
              ) : filteredTasks.length === 0 ? (
                <div className="text-center py-16 border border-dashed border-slate-800 rounded-xl">
                  <Calendar className="w-12 h-12 mx-auto mb-3 text-slate-600" />
                  <p className="text-slate-400 text-sm font-medium">No tasks found in this view.</p>
                  <p className="text-xs text-slate-500 mt-1">Create your first task above!</p>
                </div>
              ) : (
                <div className="space-y-3 max-h-[480px] overflow-y-auto pr-1">
                  {filteredTasks.map((task) => (
                    <div
                      key={task.id}
                      className={`group p-4 rounded-xl border transition-all ${
                        task.status === "completed"
                          ? "bg-slate-900/30 border-slate-900"
                          : "bg-slate-900/70 border-slate-800 hover:border-slate-700 hover:shadow-lg"
                      }`}
                    >
                      <div className="flex items-start gap-3">
                        <button
                          type="button"
                          onClick={() => toggleTaskStatus(task.id)}
                          className="mt-0.5 text-slate-500 hover:text-emerald-400 transition cursor-pointer"
                          title="Toggle Task Status"
                        >
                          {task.status === "completed" ? (
                            <CheckCircle2 className="w-5 h-5 text-emerald-400" />
                          ) : (
                            <Circle className="w-5 h-5" />
                          )}
                        </button>

                        <div className="flex-1">
                          <h3
                            className={`font-semibold text-sm ${
                              task.status === "completed" ? "line-through text-slate-500" : "text-slate-100"
                            }`}
                          >
                            {task.title}
                          </h3>

                          {task.description && (
                            <p className="text-xs text-slate-400 mt-1 leading-relaxed">{task.description}</p>
                          )}

                          <div className="flex items-center gap-3 mt-3">
                            <span
                              className={`text-[10px] uppercase font-bold px-2 py-0.5 rounded-md border ${
                                task.priority === "high"
                                  ? "text-rose-400 bg-rose-950/50 border-rose-800/60"
                                  : task.priority === "medium"
                                  ? "text-amber-400 bg-amber-950/50 border-amber-800/60"
                                  : "text-emerald-400 bg-emerald-950/50 border-emerald-800/60"
                              }`}
                            >
                              {task.priority}
                            </span>

                            <span className="text-[11px] text-slate-500 flex items-center gap-1">
                              <Clock className="w-3 h-3" />
                              {format(new Date(task.createdAt), "MMM d, h:mm a")}
                            </span>
                          </div>
                        </div>

                        <button
                          type="button"
                          onClick={() => deleteTask(task.id)}
                          className="opacity-0 group-hover:opacity-100 text-rose-400 hover:text-rose-300 p-1.5 rounded-lg hover:bg-rose-950/40 transition cursor-pointer"
                          title="Delete Task"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div className="glass-card rounded-2xl border border-slate-800 shadow-xl overflow-hidden flex flex-col h-[400px]">
              <div className="p-4 bg-slate-900/80 border-b border-slate-800 flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Bot className="w-5 h-5 text-violet-400" />
                  <h3 className="font-semibold text-sm text-white">AI Copilot Chat</h3>
                </div>
                <span className="text-[10px] font-mono bg-violet-500/10 text-violet-300 border border-violet-500/20 px-2 py-0.5 rounded-full">
                  GPT-4o-mini
                </span>
              </div>

              <div className="flex-1 overflow-y-auto p-4 space-y-3">
                {messages.map((m) => (
                  <div
                    key={m.id}
                    className={`flex ${m.role === "user" ? "justify-end" : "justify-start"}`}
                  >
                    <div
                      className={`max-w-[85%] rounded-2xl px-4 py-2.5 text-xs leading-relaxed ${
                        m.role === "user"
                          ? "bg-indigo-600 text-white rounded-br-none"
                          : "bg-slate-900 border border-slate-800 text-slate-200 rounded-bl-none"
                      }`}
                    >
                      <p className="whitespace-pre-line">{m.content}</p>
                      <span className="text-[10px] opacity-60 mt-1 block text-right">
                        {format(m.timestamp, "h:mm a")}
                      </span>
                    </div>
                  </div>
                ))}

                {isProcessing && (
                  <div className="flex justify-start">
                    <div className="bg-slate-900 border border-slate-800 rounded-2xl px-4 py-3">
                      <div className="flex gap-1.5">
                        <div className="w-1.5 h-1.5 bg-violet-400 rounded-full animate-bounce" style={{ animationDelay: "0ms" }} />
                        <div className="w-1.5 h-1.5 bg-violet-400 rounded-full animate-bounce" style={{ animationDelay: "150ms" }} />
                        <div className="w-1.5 h-1.5 bg-violet-400 rounded-full animate-bounce" style={{ animationDelay: "300ms" }} />
                      </div>
                    </div>
                  </div>
                )}
              </div>

              <form onSubmit={handleChatFormSubmit} className="p-3 bg-slate-900/60 border-t border-slate-800 flex gap-2">
                <input
                  type="text"
                  value={chatInput}
                  onChange={(e) => setChatInput(e.target.value)}
                  placeholder="Ask AI about task summary, priorities..."
                  className="flex-1 px-4 py-2 bg-slate-950 border border-slate-800 rounded-xl focus:ring-2 focus:ring-violet-500 text-xs text-white placeholder-slate-500 outline-none"
                  disabled={isProcessing}
                />
                <button
                  type="submit"
                  disabled={isProcessing || !chatInput.trim()}
                  className="bg-violet-600 hover:bg-violet-500 text-white px-4 py-2 rounded-xl transition text-xs font-medium disabled:opacity-50 flex items-center gap-1.5 cursor-pointer"
                >
                  <Send className="w-3.5 h-3.5" />
                  Send
                </button>
              </form>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}