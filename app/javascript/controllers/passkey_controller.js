import { Controller } from "@hotwired/stimulus"

// Passkeys (WebAuthn) in the browser. One controller, three uses (mode):
//   register  add a passkey to your account (profile, two-factor setup)
//   signin    "Sign in with a passkey" (also the second step); with
//             conditional, passkeys are also offered in the email field's autofill
//   confirm   confirm it's you before signing entries or downloading a backup
// The server sends options as JSON (base64url strings); the browser wants
// binary, and its answer goes back as base64url again.
export default class extends Controller {
  static targets = ["name", "password", "error", "button"]
  static values = { mode: String, optionsUrl: String, url: String, returnTo: String, conditional: Boolean }

  connect() {
    if (!window.PublicKeyCredential) {
      this.element.hidden = true
      return
    }
    if (this.conditionalValue) this.conditional()
  }

  disconnect() { this.abort?.abort() }

  async start(event) {
    event?.preventDefault()
    this.abort?.abort() // a pending autofill request would block this one
    this.showError("")
    if (this.hasButtonTarget) this.buttonTarget.disabled = true
    try {
      if (this.modeValue === "register") await this.register()
      else await this.authenticate()
    } catch (error) {
      if (error.name !== "AbortError") this.showError(this.messageFor(error))
    } finally {
      if (this.hasButtonTarget) this.buttonTarget.disabled = false
    }
  }

  async register() {
    const options = await this.post(this.optionsUrlValue, {
      name: this.hasNameTarget ? this.nameTarget.value : "",
      password: this.hasPasswordTarget ? this.passwordTarget.value : ""
    })
    const publicKey = {
      ...options,
      challenge: decode(options.challenge),
      user: { ...options.user, id: decode(options.user.id) },
      excludeCredentials: (options.excludeCredentials || []).map((c) => ({ ...c, id: decode(c.id) }))
    }
    const credential = await navigator.credentials.create({ publicKey })
    await this.finish({ credential: credentialJSON(credential), return_to: this.returnToValue })
  }

  async authenticate(mediation) {
    const options = await this.post(this.optionsUrlValue, {})
    const publicKey = {
      ...options,
      challenge: decode(options.challenge),
      allowCredentials: (options.allowCredentials || []).map((c) => ({ ...c, id: decode(c.id) }))
    }
    this.abort = new AbortController()
    const credential = await navigator.credentials.get({ publicKey, mediation, signal: this.abort.signal })
    await this.finish({ credential: credentialJSON(credential) })
  }

  // The browser offers passkeys in the email field's suggestions.
  async conditional() {
    if (!(await PublicKeyCredential.isConditionalMediationAvailable?.())) return
    try {
      await this.authenticate("conditional")
    } catch (error) {
      if (error.name !== "AbortError") this.showError(this.messageFor(error))
    }
  }

  async finish(body) {
    const result = await this.post(this.urlValue, body)
    if (result.redirect) window.Turbo ? Turbo.visit(result.redirect) : (window.location = result.redirect)
    else if (result.reload) window.Turbo ? Turbo.visit(window.location.href, { action: "replace" }) : window.location.reload()
  }

  async post(url, body) {
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json",
                 "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content },
      body: JSON.stringify(body),
      credentials: "same-origin"
    })
    const data = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(data.error || "Something went wrong. Try again.")
    return data
  }

  messageFor(error) {
    if (error.name === "NotAllowedError") return "Cancelled, or the passkey wasn't available on this device."
    if (error.name === "InvalidStateError") return "This device already has a passkey for your account."
    if (error.name === "SecurityError") return "Passkeys need this site to be opened at its secure (https) address."
    return error.message
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.hidden = !message
  }
}

function decode(value) {
  const base64 = value.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(value.length / 4) * 4, "=")
  return Uint8Array.from(atob(base64), (c) => c.charCodeAt(0)).buffer
}

function encode(buffer) {
  let binary = ""
  new Uint8Array(buffer).forEach((b) => { binary += String.fromCharCode(b) })
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}

function credentialJSON(credential) {
  const r = credential.response
  const response = { clientDataJSON: encode(r.clientDataJSON) }
  if (r.attestationObject) {
    response.attestationObject = encode(r.attestationObject)
    response.transports = r.getTransports ? r.getTransports() : []
  }
  if (r.authenticatorData) response.authenticatorData = encode(r.authenticatorData)
  if (r.signature) response.signature = encode(r.signature)
  if (r.userHandle) response.userHandle = encode(r.userHandle)
  return {
    id: credential.id, rawId: encode(credential.rawId), type: credential.type, response,
    authenticatorAttachment: credential.authenticatorAttachment,
    clientExtensionResults: credential.getClientExtensionResults ? credential.getClientExtensionResults() : {}
  }
}
