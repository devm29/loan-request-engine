import { Controller } from "stimulus"

// Drives the multi-step loan request form.
//
// One rule governs this file: it never calculates a lending figure. The review
// step asks the server for a quote and renders what comes back, so the numbers
// a borrower sees before submitting are produced by exactly the same code that
// produces the term sheet afterwards.
export default class extends Controller {
  static targets = ["step", "input", "product", "term", "review", "stepNumber", "termHint", "progress", "back", "forward", "errors"]
  static values = { currentStep: Number, quoteUrl: String, products: Object }

  connect() {
    this.showCurrentStep()
  }

  nextStep(event) {
    event.preventDefault()
    if (!this.validateForm()) return

    const nextStep = this.currentStep() + 1
    if (nextStep <= this.stepTargets.length) {
      this.setCurrentStep(nextStep)
      this.showCurrentStep()
    } else {
      this.submitForm()
    }
  }

  previousStep(event) {
    event.preventDefault()
    const previousStep = this.currentStep() - 1
    if (previousStep >= 1) {
      this.setCurrentStep(previousStep)
      this.showCurrentStep()
    }
  }

  // Validate every input inside the step being left, not just the one whose
  // index happens to match the step number: the contact step holds four.
  validateForm() {
    const stepElement = this.stepTargets[this.currentStep() - 1]
    if (!stepElement) return true

    const inputs = this.inputTargets.filter((input) => stepElement.contains(input))
    for (const input of inputs) {
      if (!input.checkValidity()) {
        input.reportValidity()
        return false
      }
    }
    return true
  }

  showCurrentStep() {
    const currentStep = this.currentStep()
    const lastStep = this.stepTargets.length

    this.stepTargets.forEach((element, index) => {
      element.classList.toggle("hidden", index !== currentStep - 1)
    })

    this.element.querySelectorAll("[data-step-index]").forEach((element) => {
      const index = parseInt(element.dataset.stepIndex, 10)
      const isCurrent = index === currentStep
      const isDone = index < currentStep
      element.classList.toggle("text-emerald-700", isCurrent)
      element.classList.toggle("text-slate-600", isDone && !isCurrent)
      element.classList.toggle("text-slate-400", !isCurrent && !isDone)
    })

    if (this.hasStepNumberTarget) this.stepNumberTarget.textContent = String(currentStep)
    if (this.hasProgressTarget) {
      this.progressTarget.style.width = `${Math.round((currentStep / lastStep) * 100)}%`
    }

    if (this.hasForwardTarget) {
      this.forwardTarget.textContent = currentStep < lastStep ? "Next" : "Request term sheet"
    }
    if (this.hasBackTarget) this.backTarget.disabled = currentStep === 1

    this.applyProductTermWindow()
    if (currentStep === lastStep) this.loadQuote()
  }

  // The chosen product decides the term window; reflect it on the input so the
  // browser rejects an out-of-range term before the server has to.
  applyProductTermWindow() {
    const product = this.productsValue[this.selectedProductCode()]
    if (!product || !this.hasTermTarget) return

    this.termTarget.min = product.min
    this.termTarget.max = product.max
    if (this.hasTermHintTarget) {
      this.termHintTarget.textContent = `${product.name} runs from ${product.min} to ${product.max} months.`
    }
  }

  async loadQuote() {
    if (!this.hasReviewTarget) return
    this.reviewTarget.innerHTML = this.placeholder("Pricing your request…")

    const payload = {
      product_code: this.selectedProductCode(),
      loan_term: this.fieldValue("loan_request_loan_term"),
      purchase_price: this.fieldValue("loan_request_purchase_price"),
      repair_budget: this.fieldValue("loan_request_repair_budget"),
      arv: this.fieldValue("loan_request_arv")
    }

    try {
      const response = await fetch(this.quoteUrlValue, {
        method: "POST",
        headers: this.jsonHeaders(),
        body: JSON.stringify({ quote: payload })
      })
      const data = await response.json()
      if (!response.ok) {
        this.reviewTarget.innerHTML = this.placeholder(
          (data.errors && data.errors[0]) || "We could not price that request."
        )
        return
      }
      this.renderQuote(data)
    } catch (error) {
      this.reviewTarget.innerHTML = this.placeholder(
        "We could not reach the pricing service. You can still submit your request."
      )
    }
  }

  renderQuote(data) {
    const f = data.quote.formatted
    const rows = [
      ["Purchase price", f.purchase_price],
      ["Repair budget", f.repair_budget],
      ["Total project cost", f.total_project_cost],
      ["After-repair value", f.arv],
      ["Maximum loan", f.max_fundable_amount],
      ["Cash you bring", f.cash_required],
      [`Interest (${f.annual_interest_rate} over ${f.term})`, f.interest_expense],
      ["Repayable at exit", f.total_repayment],
      ["Estimated profit", f.estimated_profit]
    ]

    const highlight = ["Maximum loan", "Estimated profit"]
    const table = rows
      .map(([label, value]) => {
        const strong = highlight.includes(label)
        return `<div class="flex items-baseline justify-between gap-4 border-b border-stone-100 py-2 last:border-0">
            <dt class="text-sm ${strong ? "font-semibold text-slate-900" : "text-slate-600"}">${escapeHtml(label)}</dt>
            <dd class="text-sm tabular-nums ${strong ? "font-semibold text-emerald-800" : "text-slate-900"}">${escapeHtml(value)}</dd>
          </div>`
      })
      .join("")

    const bullets = (data.explanation.bullets || [])
      .map((bullet) => `<li class="flex gap-2"><span class="text-emerald-700">&bull;</span><span>${escapeHtml(bullet)}</span></li>`)
      .join("")

    this.reviewTarget.innerHTML = `
      <div class="rounded-xl border border-emerald-200 bg-emerald-50 px-5 py-4">
        <p class="text-sm font-semibold text-emerald-900">${escapeHtml(data.explanation.headline)}</p>
        <p class="mt-1 text-xs leading-relaxed text-emerald-800">${escapeHtml(data.explanation.narrative)}</p>
      </div>
      <dl class="mt-5">${table}</dl>
      <ul class="mt-5 space-y-1.5 text-xs leading-relaxed text-slate-500">${bullets}</ul>
    `
  }

  async submitForm() {
    const form = this.element
    const errorContainer = this.errorsTarget
    this.forwardTarget.disabled = true
    this.forwardTarget.textContent = "Sending…"

    let response
    try {
      response = await fetch(form.action, {
        method: form.method,
        body: new FormData(form),
        headers: this.jsonHeaders(false)
      })
    } catch (error) {
      this.resetSubmitButton()
      errorContainer.textContent = "We could not reach the server. Check your connection and try again."
      return
    }

    let data
    try {
      data = await response.json()
    } catch (error) {
      this.resetSubmitButton()
      errorContainer.textContent = "The server returned an unexpected response. Please try again."
      return
    }

    if (!data.errors) {
      window.location.assign(data.redirect_url)
      return
    }

    this.resetSubmitButton()
    errorContainer.innerHTML = ""
    data.errors.forEach((error) => {
      const paragraph = document.createElement("p")
      paragraph.textContent = error
      errorContainer.appendChild(paragraph)
    })
  }

  resetSubmitButton() {
    this.forwardTarget.disabled = false
    this.forwardTarget.textContent = "Request term sheet"
  }

  selectedProductCode() {
    const checked = this.productTargets.find((input) => input.checked)
    return checked ? checked.value : ""
  }

  fieldValue(id) {
    const field = document.getElementById(id)
    return field ? field.value : ""
  }

  jsonHeaders(json = true) {
    const headers = {
      Accept: "application/json",
      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
    }
    if (json) headers["Content-Type"] = "application/json"
    return headers
  }

  placeholder(message) {
    return `<p class="rounded-lg bg-stone-100 px-4 py-6 text-center text-sm text-slate-500">${escapeHtml(message)}</p>`
  }

  currentStep() {
    return this.currentStepValue || 1
  }

  setCurrentStep(step) {
    this.currentStepValue = step
  }
}

function escapeHtml(value) {
  const element = document.createElement("span")
  element.textContent = value == null ? "" : String(value)
  return element.innerHTML
}
