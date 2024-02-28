import { Controller } from "stimulus"

// Waits for the background job to finish rendering the PDF.
//
// The figures on this page are already final - they are recomputed from the
// stored request, not from the job - so only the download link has anything to
// wait for. Polling stops as soon as the document exists, and gives up after a
// bounded number of attempts rather than hammering the server forever.
export default class extends Controller {
  static targets = ["message", "download"]
  static values = { statusUrl: String, ready: Boolean }

  static POLL_INTERVAL_MS = 2000
  static MAX_ATTEMPTS = 45

  connect() {
    this.attempts = 0
    if (this.readyValue) return
    this.poll()
  }

  disconnect() {
    if (this.timer) clearTimeout(this.timer)
  }

  async poll() {
    this.attempts += 1
    if (this.attempts > this.constructor.MAX_ATTEMPTS) {
      this.setMessage("This is taking longer than usual. We will still email it to you.")
      return
    }

    try {
      const response = await fetch(this.statusUrlValue, {
        headers: { Accept: "application/json" }
      })
      if (response.ok) {
        const data = await response.json()
        if (data.ready) {
          this.markReady(data.status)
          return
        }
        if (data.status === "failed") {
          this.setMessage("Something went wrong rendering your term sheet. Our team has been notified.")
          return
        }
      }
    } catch (error) {
      // A transient failure is not worth showing; the next poll will retry.
    }

    this.timer = setTimeout(() => this.poll(), this.constructor.POLL_INTERVAL_MS)
  }

  markReady(status) {
    if (this.hasDownloadTarget) {
      this.downloadTarget.classList.remove("pointer-events-none", "opacity-40")
    }
    this.setMessage(
      status === "delivered"
        ? "Emailed to you, and ready to download here."
        : "Rendered and ready to download. The email is on its way."
    )
  }

  setMessage(text) {
    if (this.hasMessageTarget) this.messageTarget.textContent = text
  }
}
