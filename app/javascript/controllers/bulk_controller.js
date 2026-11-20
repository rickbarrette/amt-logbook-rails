import { Controller } from "@hotwired/stimulus"

// Entries list: tick entries, pick an action, fill in only what that action
// needs. The bar shows how many are selected; Apply stays off until there's
// a selection and an action.
export default class extends Controller {
  static targets = ["box", "all", "count", "bar", "action", "section", "apply"]

  connect() { this.update() }

  toggleAll() {
    this.boxTargets.forEach((b) => { b.checked = this.allTarget.checked })
    this.update()
  }

  update() {
    const n = this.boxTargets.filter((b) => b.checked).length
    this.countTarget.textContent = `${n} selected`
    if (this.hasAllTarget) {
      this.allTarget.checked = n > 0 && n === this.boxTargets.length
      this.allTarget.indeterminate = n > 0 && n < this.boxTargets.length
    }
    this.barTarget.classList.toggle("opacity-60", n === 0)
    const action = this.actionTarget.value
    this.sectionTargets.forEach((s) => {
      const show = s.dataset.for.split(" ").includes(action)
      s.hidden = !show
      s.querySelectorAll("input, select").forEach((el) => { el.disabled = !show })
    })
    this.applyTarget.disabled = n === 0 || !action
  }

  confirm(event) {
    const n = this.boxTargets.filter((b) => b.checked).length
    if (this.actionTarget.value === "delete" && !window.confirm(`Delete ${n} ${n === 1 ? "entry" : "entries"}? Signed entries and ones waiting for a signature are kept.`)) {
      event.preventDefault()
    }
  }
}
