import { Controller } from "@hotwired/stimulus"

// Demo Calendar Controller
// Session-based calendar for unauthenticated users
export default class extends Controller {
  static targets = [
    "calendarDays",
    "currentMonth",
    "eventCount",
    "eventModal",
    "addEventModal",
    "modalEventType",
    "modalEventTitle",
    "modalEventDate",
    "modalEventTime",
    "modalEventLocation",
    "modalEventDescription",
    "deleteEventBtn",
    "addEventForm",
    "newEventTitle",
    "newEventType",
    "newEventDate",
    "newEventTime",
    "newEventLocation",
    "newEventDescription"
  ]

  static values = {
    eventsUrl: String,
    createUrl: String
  }

  connect() {
    this.currentDate = new Date()
    this.events = []
    this.currentEvent = null
    this.monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ]

    this.fetchEventsAndRender()
    this.setupEventListeners()
  }

  setupEventListeners() {
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        this.closeEventModal()
        this.closeAddEventModal()
      }
    })

    if (this.hasEventModalTarget) {
      this.eventModalTarget.addEventListener('click', (e) => {
        if (e.target === this.eventModalTarget) {
          this.closeEventModal()
        }
      })
    }

    if (this.hasAddEventModalTarget) {
      this.addEventModalTarget.addEventListener('click', (e) => {
        if (e.target === this.addEventModalTarget) {
          this.closeAddEventModal()
        }
      })
    }
  }

  async fetchEventsAndRender() {
    const year = this.currentDate.getFullYear()
    const month = this.currentDate.getMonth()

    const firstDay = new Date(year, month, 1)
    const lastDay = new Date(year, month + 1, 0)

    const startDate = new Date(firstDay)
    startDate.setDate(startDate.getDate() - firstDay.getDay())

    const endDate = new Date(lastDay)
    endDate.setDate(endDate.getDate() + (6 - lastDay.getDay()))

    try {
      const url = new URL(this.eventsUrlValue, window.location.origin)
      url.searchParams.set('start', startDate.toISOString())
      url.searchParams.set('end', endDate.toISOString())

      const response = await fetch(url)
      this.events = await response.json()
    } catch (error) {
      console.error('Error fetching events:', error)
      this.events = []
    }

    this.renderCalendar()
  }

  renderCalendar() {
    const year = this.currentDate.getFullYear()
    const month = this.currentDate.getMonth()

    this.currentMonthTarget.textContent = `${this.monthNames[month]} ${year}`

    const firstDay = new Date(year, month, 1).getDay()
    const daysInMonth = new Date(year, month + 1, 0).getDate()
    const daysInPrevMonth = new Date(year, month, 0).getDate()

    this.calendarDaysTarget.innerHTML = ''

    for (let i = firstDay - 1; i >= 0; i--) {
      const day = daysInPrevMonth - i
      const dayEl = this.createDayElement(day, true, month - 1, year)
      this.calendarDaysTarget.appendChild(dayEl)
    }

    const today = new Date()
    for (let day = 1; day <= daysInMonth; day++) {
      const isToday = today.getDate() === day &&
                      today.getMonth() === month &&
                      today.getFullYear() === year
      const dayEl = this.createDayElement(day, false, month, year, isToday)
      this.calendarDaysTarget.appendChild(dayEl)
    }

    const totalCells = this.calendarDaysTarget.children.length
    const remainingCells = 35 - totalCells
    for (let day = 1; day <= remainingCells; day++) {
      const dayEl = this.createDayElement(day, true, month + 1, year)
      this.calendarDaysTarget.appendChild(dayEl)
    }
  }

  createDayElement(day, isOtherMonth, month, year, isToday = false) {
    const dayEl = document.createElement('div')
    dayEl.className = 'calendar-day'
    if (isOtherMonth) dayEl.classList.add('other-month')
    if (isToday) dayEl.classList.add('today')

    const dayNumber = document.createElement('div')
    dayNumber.className = 'day-number'
    dayNumber.textContent = day
    dayEl.appendChild(dayNumber)

    const dayEvents = document.createElement('div')
    dayEvents.className = 'day-events'

    const actualMonth = month < 0 ? 11 : (month > 11 ? 0 : month)
    const actualYear = month < 0 ? year - 1 : (month > 11 ? year + 1 : year)

    const dayEventsData = this.events.filter(event => {
      const eventDate = new Date(event.start)
      return eventDate.getDate() === day &&
             eventDate.getMonth() === actualMonth &&
             eventDate.getFullYear() === actualYear
    })

    dayEventsData.forEach(event => {
      const eventChip = document.createElement('div')
      eventChip.className = `event-chip event-type-${event.eventType || 'social'}`
      if (event.isDemo) {
        eventChip.classList.add('demo-event')
      }
      eventChip.innerHTML = `<span class="event-dot"></span><span>${event.title}</span>`
      eventChip.addEventListener('click', (e) => {
        e.stopPropagation()
        this.openEventModal(event)
      })
      dayEvents.appendChild(eventChip)
    })

    dayEl.appendChild(dayEvents)

    const addHint = document.createElement('div')
    addHint.className = 'add-event-hint'
    addHint.textContent = '+'
    addHint.addEventListener('click', (e) => {
      e.stopPropagation()
      const dateStr = `${actualYear}-${String(actualMonth + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`
      this.openAddEventModal(dateStr)
    })
    dayEl.appendChild(addHint)

    return dayEl
  }

  prevMonth() {
    this.currentDate.setMonth(this.currentDate.getMonth() - 1)
    this.fetchEventsAndRender()
  }

  nextMonth() {
    this.currentDate.setMonth(this.currentDate.getMonth() + 1)
    this.fetchEventsAndRender()
  }

  openEventModal(event) {
    this.currentEvent = event

    const typeStyles = {
      social: { bg: 'linear-gradient(135deg, #caffbf 0%, #9bf6ff 100%)', color: '#2d5a4e' },
      meeting: { bg: 'linear-gradient(135deg, #ffadad 0%, #ffd6a5 100%)', color: '#8b4537' },
      workshop: { bg: 'linear-gradient(135deg, #ffc6ff 0%, #bdb2ff 100%)', color: '#5a4570' },
      celebration: { bg: 'linear-gradient(135deg, #ffd6a5 0%, #fdffb6 100%)', color: '#8b5e3c' },
      community: { bg: 'linear-gradient(135deg, #9bf6ff 0%, #a0c4ff 100%)', color: '#274060' }
    }

    const eventType = event.eventType || 'social'
    const style = typeStyles[eventType] || typeStyles.social

    this.modalEventTypeTarget.textContent = eventType.toUpperCase()
    this.modalEventTypeTarget.style.background = style.bg
    this.modalEventTypeTarget.style.color = style.color

    this.modalEventTitleTarget.textContent = event.title

    const startDate = new Date(event.start)
    const dateOptions = { weekday: 'long', year: 'numeric', month: 'short', day: 'numeric' }
    const timeOptions = { hour: 'numeric', minute: '2-digit' }

    this.modalEventDateTarget.textContent = startDate.toLocaleDateString('en-US', dateOptions)
    this.modalEventTimeTarget.textContent = startDate.toLocaleTimeString('en-US', timeOptions)
    this.modalEventLocationTarget.textContent = event.location || 'TBD'

    this.modalEventDescriptionTarget.textContent = event.description || 'No description provided.'

    // Show delete button only for demo events
    if (this.hasDeleteEventBtnTarget) {
      this.deleteEventBtnTarget.style.display = event.isDemo ? 'block' : 'none'
    }

    this.eventModalTarget.classList.add('active')
    this.eventModalTarget.setAttribute('aria-hidden', 'false')
    document.body.classList.add('modal-open')
  }

  closeEventModal() {
    if (this.hasEventModalTarget) {
      this.eventModalTarget.classList.remove('active')
      this.eventModalTarget.setAttribute('aria-hidden', 'true')
      this.currentEvent = null
      this.updateBodyModalState()
    }
  }

  openAddEventModal(prefillDate = null) {
    if (this.hasAddEventFormTarget) {
      this.addEventFormTarget.reset()
    }

    if (prefillDate && this.hasNewEventDateTarget) {
      this.newEventDateTarget.value = prefillDate
    }

    this.addEventModalTarget.classList.add('active')
    this.addEventModalTarget.setAttribute('aria-hidden', 'false')
    document.body.classList.add('modal-open')
  }

  closeAddEventModal() {
    if (this.hasAddEventModalTarget) {
      this.addEventModalTarget.classList.remove('active')
      this.addEventModalTarget.setAttribute('aria-hidden', 'true')
      this.updateBodyModalState()
    }
  }

  updateBodyModalState() {
    const anyModalOpen =
      (this.hasEventModalTarget && this.eventModalTarget.classList.contains('active')) ||
      (this.hasAddEventModalTarget && this.addEventModalTarget.classList.contains('active'))

    document.body.classList.toggle('modal-open', anyModalOpen)
  }

  async createEvent(e) {
    e.preventDefault()

    const title = this.newEventTitleTarget.value.trim()
    const eventType = this.newEventTypeTarget.value
    const date = this.newEventDateTarget.value
    const time = this.newEventTimeTarget.value
    const location = this.newEventLocationTarget.value.trim()
    const description = this.newEventDescriptionTarget.value.trim()

    if (!title || !date || !time) {
      alert('Please fill in title, date, and time.')
      return
    }

    const startsAt = new Date(`${date}T${time}:00`)

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

      const response = await fetch(this.createUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken || '',
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          event: {
            title,
            event_type: eventType,
            starts_at: startsAt.toISOString(),
            location,
            description
          }
        })
      })

      if (response.ok) {
        this.closeAddEventModal()
        this.fetchEventsAndRender()
        this.updateEventCount(1)
      } else {
        const error = await response.json()
        alert(error.error || 'Failed to create event.')
      }
    } catch (error) {
      console.error('Error creating event:', error)
      alert('Failed to create event. Please try again.')
    }
  }

  async deleteEvent() {
    if (!this.currentEvent || !this.currentEvent.isDemo) {
      return
    }

    if (!confirm('Delete this event?')) {
      return
    }

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

      const response = await fetch(`${this.createUrlValue}/${this.currentEvent.id}`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': csrfToken || ''
        }
      })

      if (response.ok) {
        this.closeEventModal()
        this.fetchEventsAndRender()
        this.updateEventCount(-1)
      } else {
        alert('Failed to delete event.')
      }
    } catch (error) {
      console.error('Error deleting event:', error)
      alert('Failed to delete event. Please try again.')
    }
  }

  updateEventCount(delta) {
    if (this.hasEventCountTarget) {
      const current = parseInt(this.eventCountTarget.textContent) || 0
      this.eventCountTarget.textContent = Math.max(0, current + delta)
    }
  }
}
