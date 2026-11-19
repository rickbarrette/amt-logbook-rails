import { Controller } from "@hotwired/stimulus"

// Looks up an N-number in the FAA registry (imported on the server) as
// it's typed, and shows the aircraft's make and model.
export default class extends Controller {
  static targets = ["input", "result"]
  static values = { url: String }

  lookup() {
    clearTimeout(this.timeout)
    const n = this.inputTarget.value.trim()
    if (n.length < 2) { this.resultTarget.textContent = ""; return }
    this.timeout = setTimeout(() => this.fetch(n), 350)
  }

  async fetch(n) {
    try {
      const response = await fetch(`${this.urlValue}?n_number=${encodeURIComponent(n)}`, { headers: { Accept: "application/json" } })
      const data = await response.json()
      if (data.found) {
        this.resultTarget.textContent = `✓ ${data.description}`
        this.resultTarget.className = "hint text-emerald-700 dark:text-emerald-400"
      } else {
        this.resultTarget.textContent = data.registry_loaded
          ? `${data.n_number} isn't in the FAA registry. It will be saved as typed.`
          : `${data.n_number} will be saved as typed (the FAA registry hasn't been imported yet).`
        this.resultTarget.className = "hint"
      }
    } catch (e) {
      this.resultTarget.textContent = ""
    }
  }
}
