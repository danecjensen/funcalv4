import { Controller } from "@hotwired/stimulus"

// Feedback controller for user feedback submission
// Captures page context and submits feedback
export default class extends Controller {
  static targets = [
    "panel",
    "form",
    "email",
    "message",
    "submitButton",
    "counter",
    "content",
    "success"
  ]

  static values = {
    submitUrl: { type: String, default: "/feedbacks" },
    open: { type: Boolean, default: false }
  }

  connect() {
    this.maxLength = 1000
    this.isSubmitting = false

    // Auto-resize textarea
    if (this.hasMessageTarget) {
      this.messageTarget.addEventListener('input', () => this.autoResize())
    }
  }

  // Toggle panel visibility
  toggle() {
    this.openValue = !this.openValue
    this.panelTarget.classList.toggle("hidden", !this.openValue)

    if (this.openValue) {
      this.showForm()
      if (this.hasMessageTarget) {
        this.messageTarget.focus()
      }
    }
  }

  open() {
    this.openValue = true
    this.panelTarget.classList.remove("hidden")
    this.showForm()
    if (this.hasMessageTarget) {
      this.messageTarget.focus()
    }
  }

  close() {
    this.openValue = false
    this.panelTarget.classList.add("hidden")

    // Reset form after closing
    setTimeout(() => {
      if (!this.openValue) {
        this.resetForm()
      }
    }, 300)
  }

  showForm() {
    if (this.hasContentTarget) {
      this.contentTarget.classList.remove("hidden")
    }
    if (this.hasSuccessTarget) {
      this.successTarget.classList.add("hidden")
    }
    if (this.hasFormTarget) {
      this.formTarget.classList.remove("hidden")
    }
  }

  showSuccess() {
    if (this.hasContentTarget) {
      this.contentTarget.classList.add("hidden")
    }
    if (this.hasFormTarget) {
      this.formTarget.classList.add("hidden")
    }
    if (this.hasSuccessTarget) {
      this.successTarget.classList.remove("hidden")
    }

    // Auto-close after 3 seconds
    setTimeout(() => {
      this.close()
    }, 3000)
  }

  resetForm() {
    if (this.hasFormTarget) {
      this.formTarget.reset()
      this.updateCounter()
      this.autoResize()
    }
  }

  // Handle form submission
  async submit(event) {
    event.preventDefault()

    if (this.isSubmitting) return

    const message = this.messageTarget.value.trim()
    if (!message) {
      this.messageTarget.focus()
      return
    }

    // Validate length
    if (message.length > this.maxLength) {
      alert(`Feedback must be ${this.maxLength} characters or less`)
      return
    }

    this.isSubmitting = true
    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.textContent = "Sending..."

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

      // Capture page context
      const pageContext = {
        url: window.location.href,
        path: window.location.pathname,
        title: document.title,
        referrer: document.referrer,
        timestamp: new Date().toISOString()
      }

      const response = await fetch(this.submitUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify({
          feedback: {
            email: this.emailTarget.value.trim() || null,
            message: message,
            page_url: pageContext.url,
            page_path: pageContext.path,
            page_title: pageContext.title,
            user_agent: navigator.userAgent,
            screen_size: `${window.screen.width}x${window.screen.height}`,
            viewport_size: `${window.innerWidth}x${window.innerHeight}`
          }
        })
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const data = await response.json()

      if (data.success) {
        this.showSuccess()
      } else {
        throw new Error(data.error || "Failed to submit feedback")
      }

    } catch (error) {
      console.error("Feedback submission error:", error)
      alert(`Sorry, there was an error submitting your feedback: ${error.message}`)
    } finally {
      this.isSubmitting = false
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.textContent = "Send Feedback"
    }
  }

  // Update character counter
  updateCounter() {
    if (!this.hasCounterTarget || !this.hasMessageTarget) return

    const length = this.messageTarget.value.length
    this.counterTarget.textContent = length

    // Visual feedback for character limit
    if (length > this.maxLength) {
      this.counterTarget.style.color = "#dc3545"
    } else if (length > this.maxLength * 0.9) {
      this.counterTarget.style.color = "#e8a756"
    } else {
      this.counterTarget.style.color = ""
    }
  }

  // Auto-resize textarea
  autoResize() {
    if (!this.hasMessageTarget) return

    const textarea = this.messageTarget
    textarea.style.height = 'auto'
    textarea.style.height = Math.min(textarea.scrollHeight, 200) + 'px'
  }
}
