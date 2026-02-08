import { Controller } from "@hotwired/stimulus"

// Feedback controller for user feedback submission
// Captures page context and submits feedback
export default class extends Controller {
  static targets = [
    "messages",
    "input",
    "form",
    "sendButton",
    "successMessage",
    "panel"
  ]

  static values = {
    apiUrl: { type: String },
    open: { type: Boolean, default: false }
  }

  connect() {
    this.isSubmitting = false
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
    if (!message || this.isSubmitting) return

    this.isSubmitting = true
    this.sendButtonTarget.disabled = true

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

      // Capture page context
      const pageContext = {
        page_url: window.location.href,
        page_title: document.title
      }

      const response = await fetch(this.apiUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify({
          feedback: {
            feedback_text: message,
            submitted_by: this.getCurrentUserEmail(),
            ...pageContext
          }
        })
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const data = await response.json()

      // Clear input
      this.inputTarget.value = ""

      // Show success message
      this.showSuccessMessage()

      // Auto-close after 3 seconds
      setTimeout(() => {
        this.close()
        this.hideSuccessMessage()
      }, 3000)

    } catch (error) {
      console.error("Feedback error:", error)
      alert(`Sorry, there was an error submitting your feedback: ${error.message}`)
    } finally {
      this.isSubmitting = false
      this.sendButtonTarget.disabled = false
    }
  }

  showSuccessMessage() {
    if (this.hasSuccessMessageTarget) {
      this.successMessageTarget.classList.remove("hidden")
      this.scrollToBottom()
    }
  }

  hideSuccessMessage() {
    if (this.hasSuccessMessageTarget) {
      this.successMessageTarget.classList.add("hidden")
    }
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  // Handle Ctrl+Enter to submit
  handleKeydown(event) {
    if (event.key === "Enter" && (event.ctrlKey || event.metaKey)) {
      event.preventDefault()
      this.submit(event)
    }
  }

  getCurrentUserEmail() {
    // Try to extract user email from page meta or other sources
    const userMeta = document.querySelector('meta[name="user-email"]')
    if (userMeta) {
      return userMeta.content
    }
    return "anonymous"
  }
}
