import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["notes"]

  fill({ params: { text } }) {
    const ta = this.notesTarget
    ta.value = ta.value.trim() ? ta.value.trimEnd() + "\n\n" + text : text
    ta.dispatchEvent(new Event("input"))
    ta.focus()
  }
}
