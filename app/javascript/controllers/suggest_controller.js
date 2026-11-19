import { Controller } from "@hotwired/stimulus"

// A text field with suggestions from the server: the user's history on
// focus, matches as they type. The server answers [{value, label, detail, history}].
export default class extends Controller {
  static targets = ["input", "list"]
  static values = { url: String }

  connect() {
    this.results = []
    this.active = -1
    this.inputTarget.setAttribute("autocomplete", "off")
    this.inputTarget.setAttribute("role", "combobox")
    this.inputTarget.setAttribute("aria-expanded", "false")
  }

  disconnect() { clearTimeout(this.timer) }

  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.fetch(), 150)
  }

  focus() { if (!this.inputTarget.value.trim()) this.fetch() }

  async fetch() {
    const q = this.inputTarget.value.trim()
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", q)
    try {
      const response = await fetch(url, { headers: { Accept: "application/json" } })
      if (!response.ok || q !== this.inputTarget.value.trim()) return
      this.results = await response.json()
    } catch { return }
    this.active = -1
    this.render()
  }

  render() {
    this.listTarget.replaceChildren(...this.results.map((item, i) => {
      const li = document.createElement("li")
      li.setAttribute("role", "option")
      li.className = "cursor-pointer px-3 py-1.5 text-sm hover:bg-sky-50 dark:hover:bg-slate-700"
      const value = document.createElement("span")
      value.className = "font-mono font-semibold"
      value.textContent = item.value
      const label = document.createElement("span")
      label.className = "ml-2"
      label.textContent = item.label || ""
      const detail = document.createElement("span")
      detail.className = "ml-2 text-xs text-slate-500 dark:text-slate-400"
      detail.textContent = item.detail || ""
      if (item.history) li.prepend(Object.assign(document.createElement("span"), { textContent: "↺ ", className: "text-slate-400" }))
      li.append(value, label, detail)
      li.addEventListener("mousedown", (event) => { event.preventDefault(); this.choose(i) })
      return li
    }))
    const open = this.results.length > 0
    this.listTarget.hidden = !open
    this.inputTarget.setAttribute("aria-expanded", String(open))
  }

  keydown(event) {
    if (this.listTarget.hidden) return
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      this.active = (this.active + (event.key === "ArrowDown" ? 1 : -1) + this.results.length) % this.results.length
      Array.from(this.listTarget.children).forEach((li, i) => li.classList.toggle("bg-sky-100", i === this.active))
    } else if (event.key === "Enter" && this.active >= 0) {
      event.preventDefault()
      this.choose(this.active)
    } else if (event.key === "Escape") {
      this.close()
    }
  }

  choose(index) {
    this.inputTarget.value = this.results[index].value
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.close()
    clearTimeout(this.timer)
  }

  blur() { setTimeout(() => this.close(), 120) }

  close() {
    this.listTarget.hidden = true
    this.inputTarget.setAttribute("aria-expanded", "false")
  }
}
