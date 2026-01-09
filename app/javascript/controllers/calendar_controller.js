import { Controller } from "@hotwired/stimulus"
import { Calendar } from "@fullcalendar/core"
import dayGridPlugin from "@fullcalendar/daygrid"
import timeGridPlugin from "@fullcalendar/timegrid"
import interactionPlugin from "@fullcalendar/interaction"

export default class extends Controller {
  static targets = ["calendar"]
  static values = {
    eventsUrl: String
  }

  connect() {
    this.calendar = new Calendar(this.calendarTarget, {
      plugins: [dayGridPlugin, timeGridPlugin, interactionPlugin],
      initialView: "dayGridMonth",
      headerToolbar: {
        left: "prev,next today",
        center: "title",
        right: "dayGridMonth,timeGridWeek,timeGridDay"
      },
      events: this.eventsUrlValue,
      eventClick: this.handleEventClick.bind(this),
      eventDisplay: "block",
      height: "auto"
    })

    this.calendar.render()
  }

  disconnect() {
    if (this.calendar) {
      this.calendar.destroy()
    }
  }

  handleEventClick(info) {
    info.jsEvent.preventDefault()

    const eventId = info.event.id
    const modal = document.getElementById("eventModal")
    const frame = document.querySelector("#eventModal turbo-frame")

    if (frame) {
      frame.src = `/calendar/${eventId}`
    }

    const bsModal = new bootstrap.Modal(modal)
    bsModal.show()
  }
}
