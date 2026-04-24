import { Controller } from "@hotwired/stimulus"

// Displays seconds remaining until the next 30-second TOTP window boundary.
// Uses wall-clock math independent of any per-user state — safe to render
// unconditionally on any page that accepts a TOTP code.
export default class extends Controller {
  static values = { template: String }

  connect() {
    this.render()
    this.interval = setInterval(() => this.render(), 1000)
  }

  disconnect() {
    if (this.interval) {
      clearInterval(this.interval)
      this.interval = null
    }
  }

  render() {
    const seconds = 30 - (Math.floor(Date.now() / 1000) % 30)
    const template = this.templateValue || "Code rotates in {seconds}s"
    this.element.innerHTML = template.replace("{seconds}", `<strong>${seconds}s</strong>`)
  }
}
