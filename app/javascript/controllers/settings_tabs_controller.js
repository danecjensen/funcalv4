import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel", "colorHex"]

  connect() {
    // Check URL hash for initial tab
    const hash = window.location.hash.replace('#', '')
    if (hash && ['general', 'scrapers', 'import'].includes(hash)) {
      this.switchToTab(hash)
    }
  }

  switch(event) {
    const tabName = event.currentTarget.dataset.tab
    this.switchToTab(tabName)
  }

  switchToTab(tabName) {
    // Update tabs
    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.tab === tabName
      tab.classList.toggle('active', isActive)
      tab.setAttribute('aria-selected', isActive)
    })

    // Update panels
    this.panelTargets.forEach(panel => {
      const isActive = panel.dataset.panel === tabName
      panel.classList.toggle('active', isActive)

      // Re-trigger animation when switching
      if (isActive) {
        panel.style.animation = 'none'
        panel.offsetHeight // Force reflow
        panel.style.animation = null
      }
    })

    // Update URL hash without scrolling
    history.replaceState(null, null, `#${tabName}`)
  }

  syncColor(event) {
    // Sync color picker with hex input
    if (this.hasColorHexTarget) {
      this.colorHexTarget.value = event.target.value.toUpperCase()
    }
  }
}
