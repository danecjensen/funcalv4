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
    "newEventDescription",
    "monthView",
    "weekView",
    "listView",
    "monthBtn",
    "weekBtn",
    "listBtn",
    "calendarGrid"
  ]

  static values = {
    eventsUrl: String,
    createUrl: String
  }

  connect() {
    this.currentDate = new Date()
    this.events = []
    this.currentEvent = null
    this.currentView = 'month'
    this.monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ]
    this.dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
    this.shortDayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

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

  prevWeek() {
    this.currentDate.setDate(this.currentDate.getDate() - 7)
    this.fetchEventsAndRender()
  }

  nextWeek() {
    this.currentDate.setDate(this.currentDate.getDate() + 7)
    this.fetchEventsAndRender()
  }

  // View switching methods
  setViewMonth() {
    this.setView('month')
  }

  setViewWeek() {
    this.setView('week')
  }

  setViewList() {
    this.setView('list')
  }

  setView(view) {
    this.currentView = view

    // Update button states
    if (this.hasMonthBtnTarget) this.monthBtnTarget.classList.toggle('active', view === 'month')
    if (this.hasWeekBtnTarget) this.weekBtnTarget.classList.toggle('active', view === 'week')
    if (this.hasListBtnTarget) this.listBtnTarget.classList.toggle('active', view === 'list')

    // Show/hide view containers
    if (this.hasMonthViewTarget) this.monthViewTarget.style.display = view === 'month' ? 'block' : 'none'
    if (this.hasWeekViewTarget) this.weekViewTarget.style.display = view === 'week' ? 'block' : 'none'
    if (this.hasListViewTarget) this.listViewTarget.style.display = view === 'list' ? 'block' : 'none'

    this.renderCurrentView()
  }

  renderCurrentView() {
    switch (this.currentView) {
      case 'week':
        this.renderWeekView()
        break
      case 'list':
        this.renderListView()
        break
      default:
        this.renderCalendar()
    }
  }

  renderWeekView() {
    if (!this.hasWeekViewTarget) return

    // Get the start of the current week (Sunday)
    const startOfWeek = new Date(this.currentDate)
    startOfWeek.setDate(startOfWeek.getDate() - startOfWeek.getDay())

    // Update title to show week range
    const endOfWeek = new Date(startOfWeek)
    endOfWeek.setDate(endOfWeek.getDate() + 6)

    const startStr = startOfWeek.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
    const endStr = endOfWeek.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
    this.currentMonthTarget.textContent = `${startStr} - ${endStr}`

    // Build week view HTML
    let html = '<div class="week-view-header">'
    html += '<div class="week-time-gutter"></div>'

    const today = new Date()
    for (let i = 0; i < 7; i++) {
      const day = new Date(startOfWeek)
      day.setDate(day.getDate() + i)
      const isToday = day.toDateString() === today.toDateString()
      html += `<div class="week-day-header ${isToday ? 'today' : ''}">
        <span class="week-day-name">${this.shortDayNames[i]}</span>
        <span class="week-day-number">${day.getDate()}</span>
      </div>`
    }
    html += '</div>'

    html += '<div class="week-view-body">'

    // Time slots from 6 AM to 11 PM
    for (let hour = 6; hour < 24; hour++) {
      const displayHour = hour === 0 ? 12 : (hour > 12 ? hour - 12 : hour)
      const ampm = hour < 12 ? 'AM' : 'PM'

      html += '<div class="week-time-row">'
      html += `<div class="week-time-label">${displayHour} ${ampm}</div>`

      for (let dayIndex = 0; dayIndex < 7; dayIndex++) {
        const day = new Date(startOfWeek)
        day.setDate(day.getDate() + dayIndex)
        const isToday = day.toDateString() === today.toDateString()

        // Find events for this hour
        const dayEvents = this.events.filter(event => {
          const eventDate = new Date(event.start)
          return eventDate.getDate() === day.getDate() &&
                 eventDate.getMonth() === day.getMonth() &&
                 eventDate.getFullYear() === day.getFullYear() &&
                 eventDate.getHours() === hour
        })

        html += `<div class="week-time-cell ${isToday ? 'today' : ''}" data-date="${day.toISOString().split('T')[0]}" data-hour="${hour}">`
        dayEvents.forEach(event => {
          html += `<div class="week-event event-type-${event.eventType || 'social'}" data-event-id="${event.id}">
            <span class="week-event-title">${event.title}</span>
          </div>`
        })
        html += '</div>'
      }
      html += '</div>'
    }

    html += '</div>'

    this.weekViewTarget.innerHTML = html

    // Add click handlers for events
    this.weekViewTarget.querySelectorAll('.week-event').forEach(el => {
      el.addEventListener('click', (e) => {
        e.stopPropagation()
        const eventId = el.dataset.eventId
        const event = this.events.find(ev => String(ev.id) === String(eventId))
        if (event) this.openEventModal(event)
      })
    })

    // Add click handlers for cells to add events
    this.weekViewTarget.querySelectorAll('.week-time-cell').forEach(el => {
      el.addEventListener('click', () => {
        const date = el.dataset.date
        this.openAddEventModal(date)
      })
    })
  }

  renderListView() {
    if (!this.hasListViewTarget) return

    const year = this.currentDate.getFullYear()
    const month = this.currentDate.getMonth()

    // Update title
    this.currentMonthTarget.textContent = `${this.monthNames[month]} ${year}`

    // Sort events by date
    const sortedEvents = [...this.events].sort((a, b) => new Date(a.start) - new Date(b.start))

    // Group events by date
    const eventsByDate = {}
    sortedEvents.forEach(event => {
      const dateKey = new Date(event.start).toDateString()
      if (!eventsByDate[dateKey]) {
        eventsByDate[dateKey] = []
      }
      eventsByDate[dateKey].push(event)
    })

    let html = '<div class="list-view-container">'

    if (Object.keys(eventsByDate).length === 0) {
      html += '<div class="list-empty"><p>No events this month</p></div>'
    } else {
      Object.keys(eventsByDate).forEach(dateKey => {
        const date = new Date(dateKey)
        const dateStr = date.toLocaleDateString('en-US', {
          weekday: 'long',
          month: 'short',
          day: 'numeric'
        })

        const isToday = date.toDateString() === new Date().toDateString()

        html += `<div class="list-date-group ${isToday ? 'today' : ''}">`
        html += `<div class="list-date-header">${dateStr}</div>`

        eventsByDate[dateKey].forEach(event => {
          const eventTime = new Date(event.start).toLocaleTimeString('en-US', {
            hour: 'numeric',
            minute: '2-digit'
          })

          html += `<div class="list-event-item event-type-${event.eventType || 'social'}" data-event-id="${event.id}">
            <div class="list-event-time">${eventTime}</div>
            <div class="list-event-content">
              <div class="list-event-title">${event.title}</div>
              ${event.location ? `<div class="list-event-location">${event.location}</div>` : ''}
            </div>
          </div>`
        })

        html += '</div>'
      })
    }

    html += '</div>'

    this.listViewTarget.innerHTML = html

    // Add click handlers
    this.listViewTarget.querySelectorAll('.list-event-item').forEach(el => {
      el.addEventListener('click', () => {
        const eventId = el.dataset.eventId
        const event = this.events.find(ev => String(ev.id) === String(eventId))
        if (event) this.openEventModal(event)
      })
    })
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
