import { Controller } from "@hotwired/stimulus"

// Colors a tag pill in/out the instant its (hidden) checkbox is toggled.
// The server still renders the initial `.active` state on page load; this keeps
// the pill in sync as the user clicks, instead of only updating after a reload.
//
// Wire-up (people/_form.html.erb):
//   <div data-controller="tag-toggle" data-action="change->tag-toggle#toggle"> … </div>
export default class extends Controller {
  connect() {
    this.element
      .querySelectorAll('input[type="checkbox"]')
      .forEach((checkbox) => this.#paint(checkbox))
  }

  toggle(event) {
    if (event.target.type === "checkbox") this.#paint(event.target)
  }

  #paint(checkbox) {
    const label = checkbox.closest(".tag-checkbox-label")
    if (label) label.classList.toggle("active", checkbox.checked)
  }
}
