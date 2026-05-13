import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  inputChanged() {
    if (this.hasInputTarget && this.inputTarget.value === "") {
      this.element.requestSubmit()
    }
  }
}
