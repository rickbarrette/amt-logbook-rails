import { Controller } from "@hotwired/stimulus"

// ← and → move to the previous / next entry, unless you're typing.
export default class extends Controller {
  static targets = ["previous", "next"]

  connect() {
    this.onKey = (event) => {
      if (event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return
      if (event.target.closest("input, textarea, select, [contenteditable]")) return
      const link = event.key === "ArrowLeft" ? this.previousTargets[0] : event.key === "ArrowRight" ? this.nextTargets[0] : null
      if (!link) return
      event.preventDefault()
      link.click()
    }
    document.addEventListener("keydown", this.onKey)
  }

  disconnect() { document.removeEventListener("keydown", this.onKey) }
}
