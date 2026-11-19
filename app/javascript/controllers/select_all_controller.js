import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["box", "count"]

  toggle(event) {
    this.boxTargets.forEach((b) => { b.checked = event.target.checked })
    this.update()
  }

  update() {
    if (this.hasCountTarget) this.countTarget.textContent = this.boxTargets.filter((b) => b.checked).length
  }

  connect() { this.update() }
}
