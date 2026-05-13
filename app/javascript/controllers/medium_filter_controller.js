import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pill", "row"]

  filter(event) {
    const selected = event.currentTarget.dataset.medium

    this.pillTargets.forEach(pill => {
      pill.classList.toggle("active", pill.dataset.medium === selected)
    })

    this.rowTargets.forEach(row => {
      row.hidden = selected !== "all" && row.dataset.medium !== selected
    })
  }
}
