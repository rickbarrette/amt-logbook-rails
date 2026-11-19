import { Controller } from "@hotwired/stimulus"

// Registers the service worker that makes the app installable and shows an
// offline page when there's no connection.
export default class extends Controller {
  connect() {
    if ("serviceWorker" in navigator && !window.__swRegistered) {
      window.__swRegistered = true
      navigator.serviceWorker.register("/service-worker", { scope: "/" }).catch(() => {})
    }
  }
}
