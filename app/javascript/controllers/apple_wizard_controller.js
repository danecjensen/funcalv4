import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "prevBtn", "nextBtn", "urlInput", "urlError", "submitBtn", "form"]

  connect() {
    this.currentStep = 1
    this.totalSteps = 3
    this.updateButtons()
  }

  next() {
    if (this.currentStep < this.totalSteps) {
      this.currentStep++
      this.showStep()
      this.updateButtons()
    }
  }

  prev() {
    if (this.currentStep > 1) {
      this.currentStep--
      this.showStep()
      this.updateButtons()
    }
  }

  showStep() {
    this.stepTargets.forEach(el => {
      const step = parseInt(el.dataset.step)
      el.classList.toggle("d-none", step !== this.currentStep)
    })
  }

  updateButtons() {
    this.prevBtnTarget.disabled = this.currentStep === 1
    this.nextBtnTarget.classList.toggle("d-none", this.currentStep === this.totalSteps)
  }

  validateUrl() {
    const url = this.urlInputTarget.value.trim()
    const valid = /^(webcal|https?):\/\/.+/.test(url)

    this.urlInputTarget.classList.toggle("is-invalid", url.length > 0 && !valid)
    this.urlInputTarget.classList.toggle("is-valid", valid)

    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.disabled = !valid
    }
  }
}
