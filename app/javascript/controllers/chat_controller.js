import { Controller } from "@hotwired/stimulus"

// Chat controller for calendar assistant
// Provides natural language event creation, queries, and recommendations
export default class extends Controller {
  static targets = [
    "messages",
    "input",
    "form",
    "sendButton",
    "typingIndicator",
    "panel"
  ]

  static values = {
    apiUrl: { type: String, default: "/api/v1/chat" },
    open: { type: Boolean, default: false }
  }

  connect() {
    this.conversationHistory = []
    this.isStreaming = false

    // Load conversation from session storage
    this.loadConversation()

    // Focus input when panel opens
    if (this.openValue) {
      this.inputTarget.focus()
    }
  }

  disconnect() {
    // Save conversation to session storage
    this.saveConversation()
  }

  // Toggle panel visibility
  toggle() {
    this.openValue = !this.openValue
    this.panelTarget.classList.toggle("hidden", !this.openValue)

    if (this.openValue) {
      this.inputTarget.focus()
      this.scrollToBottom()
    }
  }

  open() {
    this.openValue = true
    this.panelTarget.classList.remove("hidden")
    this.inputTarget.focus()
    this.scrollToBottom()
  }

  close() {
    this.openValue = false
    this.panelTarget.classList.add("hidden")
  }

  // Handle form submission
  async submit(event) {
    event.preventDefault()

    const message = this.inputTarget.value.trim()
    if (!message || this.isStreaming) return

    // Clear input
    this.inputTarget.value = ""

    // Add user message to UI
    this.addMessage("user", message)

    // Add to conversation history
    this.conversationHistory.push({ role: "user", content: message })

    // Show typing indicator
    this.showTypingIndicator()

    // Send to API
    await this.sendMessage(message)
  }

  async sendMessage(message) {
    this.isStreaming = true
    this.sendButtonTarget.disabled = true

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

      const response = await fetch(this.apiUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "text/event-stream",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify({
          message: message,
          conversation: this.conversationHistory.slice(-10) // Last 10 messages for context
        })
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      // Hide typing indicator and create assistant message
      this.hideTypingIndicator()
      const assistantMessageEl = this.addMessage("assistant", "")
      const contentEl = assistantMessageEl.querySelector(".chat-message-content")

      // Check if streaming response
      const contentType = response.headers.get("content-type")

      if (contentType?.includes("text/event-stream")) {
        // Stream the response
        await this.streamResponse(response, contentEl)
      } else {
        // Regular JSON response
        const data = await response.json()
        contentEl.textContent = data.response || data.error || "No response"
        this.conversationHistory.push({ role: "assistant", content: contentEl.textContent })
      }

    } catch (error) {
      console.error("Chat error:", error)
      this.hideTypingIndicator()
      this.addMessage("assistant", `Sorry, there was an error: ${error.message}`)
    } finally {
      this.isStreaming = false
      this.sendButtonTarget.disabled = false
      this.inputTarget.focus()
      this.saveConversation()
    }
  }

  async streamResponse(response, contentEl) {
    const reader = response.body.getReader()
    const decoder = new TextDecoder()
    let fullContent = ""
    let buffer = ""

    try {
      while (true) {
        const { done, value } = await reader.read()
        if (done) break

        buffer += decoder.decode(value, { stream: true })

        // Process complete SSE messages
        const lines = buffer.split("\n")
        buffer = lines.pop() || "" // Keep incomplete line in buffer

        for (const line of lines) {
          if (line.startsWith("data: ")) {
            const data = line.slice(6)

            if (data === "[DONE]") {
              break
            }

            try {
              const parsed = JSON.parse(data)

              if (parsed.content) {
                fullContent += parsed.content
                contentEl.textContent = fullContent
                this.scrollToBottom()
              }

              if (parsed.error) {
                contentEl.textContent = `Error: ${parsed.error}`
              }

              // Handle tool results (event creation, etc.)
              if (parsed.tool_result) {
                this.handleToolResult(parsed.tool_result)
              }

            } catch (e) {
              // Not JSON, might be plain text chunk
              fullContent += data
              contentEl.textContent = fullContent
            }
          }
        }
      }
    } finally {
      reader.releaseLock()
    }

    // Add to conversation history
    if (fullContent) {
      this.conversationHistory.push({ role: "assistant", content: fullContent })
    }
  }

  handleToolResult(result) {
    // Handle tool results like event creation
    if (result.type === "event_created") {
      // Could trigger a calendar refresh or show a notification
      this.dispatch("eventCreated", { detail: result.event })
    }
  }

  addMessage(role, content) {
    const messageEl = document.createElement("div")
    messageEl.className = `chat-message chat-message-${role}`

    const avatarEl = document.createElement("div")
    avatarEl.className = "chat-message-avatar"
    avatarEl.textContent = role === "user" ? "You" : "AI"

    const contentEl = document.createElement("div")
    contentEl.className = "chat-message-content"
    contentEl.textContent = content

    messageEl.appendChild(avatarEl)
    messageEl.appendChild(contentEl)

    this.messagesTarget.appendChild(messageEl)
    this.scrollToBottom()

    return messageEl
  }

  showTypingIndicator() {
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.classList.remove("hidden")
      this.scrollToBottom()
    }
  }

  hideTypingIndicator() {
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.classList.add("hidden")
    }
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  // Handle Enter key (submit) vs Shift+Enter (newline)
  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.submit(event)
    }
  }

  // Persistence
  saveConversation() {
    try {
      sessionStorage.setItem("funcal_chat_history", JSON.stringify(this.conversationHistory.slice(-20)))
    } catch (e) {
      // Storage might be full or disabled
    }
  }

  loadConversation() {
    try {
      const saved = sessionStorage.getItem("funcal_chat_history")
      if (saved) {
        this.conversationHistory = JSON.parse(saved)
        // Restore messages to UI
        for (const msg of this.conversationHistory) {
          this.addMessage(msg.role, msg.content)
        }
      }
    } catch (e) {
      this.conversationHistory = []
    }
  }

  clearHistory() {
    this.conversationHistory = []
    this.messagesTarget.innerHTML = ""
    sessionStorage.removeItem("funcal_chat_history")
    this.addWelcomeMessage()
  }

  addWelcomeMessage() {
    this.addMessage("assistant",
      "Hi! I'm your calendar assistant. I can help you:\n" +
      "- Create events: \"Add lunch with Sarah tomorrow at noon\"\n" +
      "- Find events: \"What's happening this weekend?\"\n" +
      "- Get recommendations: \"Find me something fun to do\"\n\n" +
      "How can I help?"
    )
  }
}
