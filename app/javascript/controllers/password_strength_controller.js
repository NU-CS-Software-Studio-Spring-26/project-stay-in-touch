import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "confirm", "toggleBtn", "length", "uppercase", "lowercase", "number", "special"]

  check() {
    const val = this.inputTarget.value

    this.#rule(this.lengthTarget,    val.length > 10)
    this.#rule(this.uppercaseTarget, /[A-Z]/.test(val))
    this.#rule(this.lowercaseTarget, /[a-z]/.test(val))
    this.#rule(this.numberTarget,    /\d/.test(val))
    this.#rule(this.specialTarget,   /[^A-Za-z\d\s]/.test(val))
  }

  toggle() {
    const input = this.inputTarget
    const isPassword = input.type === "password"
    input.type = isPassword ? "text" : "password"
    this.toggleBtnTarget.innerHTML = isPassword
      ? '<i class="bi bi-eye-slash"></i>'
      : '<i class="bi bi-eye"></i>'
  }

  #rule(el, passing) {
    el.querySelector(".bi").className = passing
      ? "bi bi-check-circle-fill text-success"
      : "bi bi-circle text-secondary"
    el.classList.toggle("text-success", passing)
    el.classList.toggle("text-secondary", !passing)
  }
}
