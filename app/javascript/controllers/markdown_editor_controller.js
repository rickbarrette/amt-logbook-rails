import { Controller } from "@hotwired/stimulus"

// Markdown textarea with a formatting bar and Write / Preview tabs. The
// preview is rendered by the server with the same rules as saved entries.
export default class extends Controller {
  static targets = ["input", "output", "writeTab", "previewTab", "toolbar"]
  static values = { url: String }

  connect() { this.select(false) }

  write() { this.select(false); this.inputTarget.focus() }

  async preview() {
    this.select(true)
    this.outputTarget.textContent = "Loading…"
    const token = document.querySelector("meta[name=csrf-token]")?.content
    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded", "X-CSRF-Token": token, Accept: "text/html" },
        body: new URLSearchParams({ text: this.inputTarget.value }),
        credentials: "same-origin"
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      const html = await response.text() // sanitized server-side
      this.outputTarget.innerHTML = this.inputTarget.value.trim() ? html : "<p class='muted'>Nothing to preview.</p>"
    } catch (error) {
      this.outputTarget.textContent = `Couldn't load the preview (${error.message}).`
    }
  }

  select(previewing) {
    this.inputTarget.hidden = previewing
    this.outputTarget.hidden = !previewing
    if (this.hasToolbarTarget) this.toolbarTarget.classList.toggle("invisible", previewing)
    ;[[this.writeTabTarget, !previewing], [this.previewTabTarget, previewing]].forEach(([tab, active]) => {
      tab.setAttribute("aria-selected", active)
      tab.classList.toggle("font-semibold", active)
      tab.classList.toggle("border-sky-600", active)
      tab.classList.toggle("border-transparent", !active)
    })
  }

  // --- Formatting bar ---
  bold() { this.wrap("**") }
  italic() { this.wrap("_") }
  code() { this.wrap("`") }
  bullets() { this.prefixLines(() => "- ") }
  numbers() { this.prefixLines((i) => `${i + 1}. `) }
  heading() { this.prefixLines(() => "### ") }

  link() {
    const { selectionStart: s, selectionEnd: e, value } = this.inputTarget
    const text = value.slice(s, e) || "text"
    this.replace(s, e, `[${text}](https://)`, s + text.length + 3, s + text.length + 11)
  }

  wrap(mark) {
    const { selectionStart: s, selectionEnd: e, value } = this.inputTarget
    const text = value.slice(s, e)
    if (text.startsWith(mark) && text.endsWith(mark) && text.length >= mark.length * 2) {
      const inner = text.slice(mark.length, text.length - mark.length)
      return this.replace(s, e, inner, s, s + inner.length)
    }
    this.replace(s, e, `${mark}${text}${mark}`, s + mark.length, e + mark.length)
  }

  // Adds (or removes, when every line has it) a prefix on the selected lines.
  prefixLines(prefixFor) {
    const input = this.inputTarget
    const value = input.value
    const start = value.lastIndexOf("\n", input.selectionStart - 1) + 1
    let end = value.indexOf("\n", input.selectionEnd)
    if (end === -1) end = value.length
    const lines = value.slice(start, end).split("\n")
    const marker = /^(\s*)([-*+] |\d+\. |#{1,6} )/
    const all = lines.every((l, i) => l.startsWith(prefixFor(i)))
    const updated = lines.map((l, i) => all ? l.slice(prefixFor(i).length) : prefixFor(i) + l.replace(marker, "$1")).join("\n")
    this.replace(start, end, updated, start, start + updated.length)
  }

  replace(from, to, text, selStart, selEnd) {
    const input = this.inputTarget
    input.focus()
    input.setRangeText(text, from, to)
    input.setSelectionRange(selStart, selEnd)
    input.dispatchEvent(new Event("input", { bubbles: true }))
  }

  // Ctrl/Cmd+B and +I, and continuing a list on Enter.
  keydown(event) {
    if ((event.metaKey || event.ctrlKey) && !event.altKey) {
      if (event.key === "b") { event.preventDefault(); return this.bold() }
      if (event.key === "i") { event.preventDefault(); return this.italic() }
    }
    if (event.key === "Enter" && !event.shiftKey) {
      const input = this.inputTarget
      const lineStart = input.value.lastIndexOf("\n", input.selectionStart - 1) + 1
      const line = input.value.slice(lineStart, input.selectionStart)
      const m = line.match(/^(\s*)([-*+]|(\d+)\.)\s+(.*)$/)
      if (!m) return
      event.preventDefault()
      if (!m[4]) return this.replace(lineStart, input.selectionStart, "", lineStart, lineStart) // empty item ends the list
      const next = m[3] ? `${parseInt(m[3], 10) + 1}.` : m[2]
      const insert = `\n${m[1]}${next} `
      const pos = input.selectionStart
      this.replace(pos, input.selectionEnd, insert, pos + insert.length, pos + insert.length)
    }
  }
}
