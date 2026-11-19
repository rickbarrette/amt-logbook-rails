import { Controller } from "@hotwired/stimulus"

// Suggests a category, ATA chapter and ACS subject areas from the
// description as it's typed; "Use" fills them in (nothing changes on its own).
export default class extends Controller {
  static targets = ["description", "chip", "text"]
  static values = { url: String }

  connect() { if (this.descriptionTarget.value.trim()) this.fetch() }

  changed() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.fetch(), 500)
  }

  async fetch() {
    const text = this.descriptionTarget.value
    if (text.trim().length < 4) { this.chipTarget.hidden = true; return }
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("text", text)
    try {
      const response = await fetch(url, { headers: { Accept: "application/json" } })
      this.suggestion = await response.json()
    } catch { return }
    if (!this.suggestion.found || this.alreadyApplied()) { this.chipTarget.hidden = true; return }
    const s = this.suggestion
    const areas = s.subject_areas.map((a) => a.label).join(", ")
    this.textTarget.textContent = `${s.category_label} · ATA ${s.ata_label}${areas ? ` · ${areas}` : ""}`
    this.chipTarget.hidden = false
  }

  alreadyApplied() {
    const s = this.suggestion
    const ata = this.element.querySelector("[name='work_entry[ata_chapter]']")
    const cat = this.element.querySelector(`[name='work_entry[category]'][value='${s.category}']`)
    const areas = s.subject_areas.every((a) => this.element.querySelector(`#sa_${CSS.escape(a.code)}`)?.checked)
    return ata?.value === s.ata_chapter && cat?.checked && areas
  }

  apply() {
    const s = this.suggestion
    if (!s?.found) return
    const ata = this.element.querySelector("[name='work_entry[ata_chapter]']")
    if (ata) ata.value = s.ata_chapter
    const cat = this.element.querySelector(`[name='work_entry[category]'][value='${s.category}']`)
    if (cat) cat.checked = true
    s.subject_areas.forEach((a) => {
      const box = this.element.querySelector(`#sa_${CSS.escape(a.code)}`)
      if (box) box.checked = true
    })
    const details = this.element.querySelector("details[data-acs]")
    if (details && s.subject_areas.length) {
      details.open = true
      const count = details.querySelector("[data-acs-count]")
      if (count) count.textContent = `(${details.querySelectorAll("input[type=checkbox]:checked").length} selected)`
    }
    this.chipTarget.hidden = true
  }

  dismiss() { this.chipTarget.hidden = true }
}
