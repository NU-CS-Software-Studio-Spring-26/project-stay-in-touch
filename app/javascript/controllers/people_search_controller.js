import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "row"]

  filter() {
    const query = this.inputTarget.value.toLowerCase()
    this.rowTargets.forEach(row => {
      row.hidden = !row.dataset.name.toLowerCase().includes(query)
    })
  }
}
