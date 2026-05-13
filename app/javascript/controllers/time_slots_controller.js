import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dateInput", "slots"]

  connect() {
    this.lastDate = null
    if (this.dateInputTarget.value) this.#fetchSlots()
  }

  onDateChange() {
    this.#fetchSlots()
  }

  selectSlot(event) {
    const { time, date } = event.currentTarget.dataset
    this.dateInputTarget.value = `${date}T${time}`
    this.slotsTarget.querySelectorAll("button").forEach(btn => {
      const active = btn.dataset.time === time
      btn.classList.toggle("btn-primary", active)
      btn.classList.toggle("btn-outline-secondary", !active)
    })
  }

  async #fetchSlots() {
    const value = this.dateInputTarget.value
    if (!value) return
    const date = value.split("T")[0]
    if (date === this.lastDate) return
    this.lastDate = date

    this.slotsTarget.innerHTML = '<span class="text-muted small">Checking calendar…</span>'

    try {
      const tz  = Intl.DateTimeFormat().resolvedOptions().timeZone
      const res = await fetch(`/events/available_slots?date=${date}&tz=${encodeURIComponent(tz)}`)
      const slots = await res.json()
      this.#render(slots, date)
    } catch {
      this.slotsTarget.innerHTML = ""
    }
  }

  #render(slots, date) {
    if (!slots.length) {
      this.slotsTarget.innerHTML = '<span class="text-muted small">No free slots found</span>'
      return
    }

    const selected = this.dateInputTarget.value.split("T")[1] ?? ""
    const pills = slots.map(({ value, label }) => {
      const active = value === selected
      return `<button type="button"
        class="btn btn-sm ${active ? "btn-primary" : "btn-outline-secondary"}"
        data-action="click->time-slots#selectSlot"
        data-time="${value}"
        data-date="${date}">${label}</button>`
    }).join("")

    this.slotsTarget.innerHTML =
      `<p class="text-muted small mb-1">Free slots from your calendar:</p>
       <div class="d-flex flex-wrap gap-1">${pills}</div>`
  }
}
