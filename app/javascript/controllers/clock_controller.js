import { Controller } from "@hotwired/stimulus"

// Shows a server-side timer ticking. The server sends when the clock last
// started (ms since epoch, 0 when paused) and the seconds banked before
// that, so the display is right even after the app was closed for hours.
export default class extends Controller {
  static values = { start: Number, accumulated: Number }

  connect() {
    this.render()
    if (this.startValue) this.interval = setInterval(() => this.render(), 1000)
  }

  disconnect() { clearInterval(this.interval) }

  render() {
    const running = this.startValue ? Math.max(0, Math.floor((Date.now() - this.startValue) / 1000)) : 0
    const total = this.accumulatedValue + running
    const h = Math.floor(total / 3600), m = Math.floor((total % 3600) / 60), s = total % 60
    this.element.textContent = `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`
  }
}
