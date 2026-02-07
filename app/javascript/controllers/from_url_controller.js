import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { pollUrl: String, calendarUrl: String }
  static targets = [
    "heading", "subtitle", "loading", "eventsList", "complete",
    "error", "errorMessage", "eventCount", "viewCalendarBtn", "progressBar"
  ]

  connect() {
    this.renderedCount = 0
    this.startProgress()
    this.startPolling()
  }

  disconnect() {
    this.stopPolling()
    this.stopProgress = true
  }

  startPolling() {
    this.poll()
    this.timer = setInterval(() => this.poll(), 1500)
  }

  stopPolling() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  async poll() {
    try {
      const response = await fetch(this.pollUrlValue)
      if (!response.ok) return

      const data = await response.json()

      if (data.events && data.events.length > this.renderedCount) {
        this.renderEvents(data.events)
      }

      if (data.status === "completed") {
        this.stopPolling()
        this.showComplete(data.event_count)
      } else if (data.status === "failed") {
        this.stopPolling()
        this.showError(data.error || "Extraction failed. Please try again.")
      } else if (data.status === "processing") {
        this.loadingTarget.querySelector(".extraction-loading-text").textContent =
          "Extracting events..."
      }
    } catch (e) {
      // Network error, keep polling
    }
  }

  renderEvents(events) {
    this.eventsListTarget.style.display = "block"

    events.slice(this.renderedCount).forEach((event, i) => {
      const el = document.createElement("div")
      el.className = "extraction-event-item"
      el.style.animationDelay = `${i * 0.08}s`

      const dateStr = this.formatDate(event.starts_at)
      const typeClass = event.event_type || "social"

      el.innerHTML = `
        <div class="extraction-event-badge ${typeClass}">${this.capitalize(typeClass)}</div>
        <div class="extraction-event-info">
          <strong>${this.escapeHtml(event.title)}</strong>
          <span class="extraction-event-meta">
            ${dateStr}${event.location ? ` &middot; ${this.escapeHtml(event.location)}` : ""}
          </span>
          ${event.description ? `<p class="extraction-event-desc">${this.escapeHtml(event.description)}</p>` : ""}
        </div>
      `
      this.eventsListTarget.appendChild(el)
    })

    this.renderedCount = events.length
  }

  startProgress() {
    if (!this.hasProgressBarTarget) return
    this.progressStartTime = Date.now()
    this.progressDuration = 20000
    this.stopProgress = false
    this.animateProgress()
  }

  animateProgress() {
    if (this.stopProgress) return
    const elapsed = Date.now() - this.progressStartTime
    const pct = Math.min((elapsed / this.progressDuration) * 100, 95)
    this.progressBarTarget.style.width = `${pct}%`
    if (pct < 95) {
      requestAnimationFrame(() => this.animateProgress())
    }
  }

  showComplete(count) {
    this.loadingTarget.style.display = "none"
    this.eventCountTarget.textContent = count
    this.completeTarget.style.display = "block"
    this.headingTarget.textContent = "Extraction Complete"
  }

  showError(message) {
    this.loadingTarget.style.display = "none"
    this.errorTarget.style.display = "block"
    this.errorMessageTarget.textContent = message
    this.headingTarget.textContent = "Extraction Failed"
  }

  formatDate(iso) {
    if (!iso) return ""
    try {
      const d = new Date(iso)
      return d.toLocaleDateString("en-US", {
        weekday: "short", month: "short", day: "numeric",
        hour: "numeric", minute: "2-digit"
      })
    } catch {
      return iso
    }
  }

  capitalize(str) {
    return str.charAt(0).toUpperCase() + str.slice(1)
  }

  escapeHtml(str) {
    if (!str) return ""
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
