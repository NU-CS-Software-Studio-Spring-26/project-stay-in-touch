import { Controller } from "@hotwired/stimulus"

// Makes unsaved edits obvious. Snapshots the form on connect; whenever the
// current values differ from that snapshot it reveals an "unsaved changes"
// banner, highlights the Save button, and guards against leaving the page
// (closing the tab via beforeunload, or in-app Turbo navigation like Cancel).
// Reverting every field back to its original value clears the warning.
//
// Wire-up (people/_form.html.erb):
//   <%= form_with …, data: {
//         controller: "dirty-form",
//         action: "input->dirty-form#check change->dirty-form#check " +
//                 "submit->dirty-form#markSaved" } %>
//     <div data-dirty-form-target="indicator" hidden> … </div>
export default class extends Controller {
  static targets = ["indicator"]

  connect() {
    this.clean = this.#snapshot()
    this.dirty = false

    this.beforeUnload = (event) => {
      if (!this.dirty) return
      event.preventDefault()
      event.returnValue = "" // required for the native prompt in some browsers
    }
    this.beforeVisit = (event) => {
      if (this.dirty && !window.confirm("You have unsaved changes. Leave without saving?")) {
        event.preventDefault()
      }
    }

    window.addEventListener("beforeunload", this.beforeUnload)
    document.addEventListener("turbo:before-visit", this.beforeVisit)
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.beforeUnload)
    document.removeEventListener("turbo:before-visit", this.beforeVisit)
  }

  check() {
    this.dirty = this.#snapshot() !== this.clean
    this.element.classList.toggle("is-dirty", this.dirty)
    if (this.hasIndicatorTarget) this.indicatorTarget.hidden = !this.dirty
  }

  // The form is being submitted, so the pending edits are about to be saved —
  // drop the guard so the submission/redirect isn't blocked.
  markSaved() {
    this.dirty = false
  }

  #snapshot() {
    return new URLSearchParams(new FormData(this.element)).toString()
  }
}
