import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "length", "uppercase", "lowercase", "number", "special"]

  check() {
    const val = this.inputTarget.value

    this.#rule(this.lengthTarget,    val.length > 10)
    this.#rule(this.uppercaseTarget, /[A-Z]/.test(val))
    this.#rule(this.lowercaseTarget, /[a-z]/.test(val))
    this.#rule(this.numberTarget,    /\d/.test(val))
    this.#rule(this.specialTarget,   /[^A-Za-z\d\s]/.test(val))
  }

  // Works for any input-group toggle button — finds its own sibling input.
  toggle(event) {
    const btn   = event.currentTarget
    const input = btn.closest(".input-group").querySelector("input")
    const showing = input.type === "text"
    input.type  = showing ? "password" : "text"
    btn.innerHTML = showing
      ? '<i class="bi bi-eye"></i>'
      : '<i class="bi bi-eye-slash"></i>'
  }

  #rule(el, passing) {
    el.querySelector(".bi").className = passing
      ? "bi bi-check-circle-fill text-success"
      : "bi bi-circle text-secondary"
    el.classList.toggle("text-success", passing)
    el.classList.toggle("text-secondary", !passing)
  }
}
