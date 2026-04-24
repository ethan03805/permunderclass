import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "theme"
const DARK = "dark"
const LIGHT = "light"

export default class extends Controller {
  connect() {
    this.applyTheme(this.currentTheme())
  }

  toggle() {
    const next = this.currentTheme() === DARK ? LIGHT : DARK
    this.storeTheme(next)
    this.applyTheme(next)
  }

  currentTheme() {
    try {
      const saved = localStorage.getItem(STORAGE_KEY)
      if (saved === DARK || saved === LIGHT) return saved
    } catch (_) {}
    return document.documentElement.getAttribute("data-theme") || LIGHT
  }

  storeTheme(theme) {
    try {
      localStorage.setItem(STORAGE_KEY, theme)
    } catch (_) {}
  }

  applyTheme(theme) {
    document.documentElement.setAttribute("data-theme", theme)
    this.element.setAttribute("aria-pressed", theme === DARK ? "true" : "false")
  }
}
