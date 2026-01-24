import { Controller } from "@hotwired/stimulus"

/**
 * Virtual Log Scroller Controller - Simplified
 *
 * Uses a single server endpoint that handles both regular viewing and search.
 * The server does all the heavy lifting (ripgrep search, line selection, rendering).
 * The client just specifies: position (%), search query, viewport size.
 */
export default class extends Controller {
  static targets = [
    "viewport",           // The scrollable container
    "content",            // The content area with actual height
    "linesContainer",     // Container for rendered log lines
    "progressBar",        // Green progress indicator
    "progressPosition",   // Draggable position marker
    "progressContainer",  // Progress bar container
    "progressTooltip",    // Tooltip showing line info
    "statusText",         // Status text (Line X of Y)
    "searchInput",        // Search input field
    "searchCount",        // Search results count
    "loadingOverlay",     // Loading indicator
    "topBtn",             // Scroll to top button
    "bottomBtn"           // Scroll to bottom button
  ]

  static values = {
    viewUrl: String,       // URL for the unified view endpoint
    totalLines: Number,    // Total lines in file
    lineHeight: { type: Number, default: 24 },
    bufferLines: { type: Number, default: 50 },
    viewportCount: { type: Number, default: 200 },
    streamTarget: String,  // Turbo Stream target ID for live updates
    initialQuery: String,  // Initial search query from URL
    initialTotalMatches: Number,  // Total matches for initial query (pre-rendered)
    startAtEnd: { type: Boolean, default: false }  // Start at end of file (for RCON)
  }

  connect() {
    this.currentQuery = this.initialQueryValue || ''
    this.totalMatches = null  // null means not searching
    this.isDragging = false
    this.currentPercent = 0
    this.pendingRequest = null
    this.loadedStartIndex = 0
    this.loadedEndIndex = 0

    // Set up the virtual scroll height
    this.updateContentHeight()

    // Set up scroll listener (for mousewheel scrolling)
    this.boundHandleScroll = this.debounce(this.handleScroll.bind(this), 50)
    this.viewportTarget.addEventListener('scroll', this.boundHandleScroll, { passive: true })

    // Set up keyboard shortcuts
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener('keydown', this.boundHandleKeydown)

    // Set up progress bar interactions
    this.setupProgressBar()

    // Set up log line click handler for raw view toggle
    this.boundHandleLogLineClick = this.handleLogLineClick.bind(this)
    this.linesContainerTarget.addEventListener('click', this.boundHandleLogLineClick)

    // Listen for Turbo Stream updates
    this.boundHandleTurboStream = this.handleTurboStreamAppend.bind(this)
    document.addEventListener('turbo:before-stream-render', this.boundHandleTurboStream)

    // Check if we have pre-rendered lines (server-side rendered for non-JS fallback)
    const preRenderedLines = this.linesContainerTarget.querySelectorAll('.virtual-line')
    if (preRenderedLines.length > 0) {
      // Use pre-rendered content, update tracking
      this.loadedStartIndex = 0
      this.loadedEndIndex = preRenderedLines.length
      this.currentPercent = 0
      // If we have an initial query with pre-rendered results, set totalMatches
      if (this.currentQuery && this.hasInitialTotalMatchesValue) {
        this.totalMatches = this.initialTotalMatchesValue
      }
      this.updateProgressPosition(0)
      this.updateStatusText()
      this.updateSearchCount()
    } else {
      // Initial load - start at end if configured (for RCON)
      const initialPercent = this.startAtEndValue ? 100 : 0
      this.loadAtPercent(initialPercent)
    }
  }

  disconnect() {
    this.viewportTarget.removeEventListener('scroll', this.boundHandleScroll)
    document.removeEventListener('keydown', this.boundHandleKeydown)
    this.linesContainerTarget.removeEventListener('click', this.boundHandleLogLineClick)
    document.removeEventListener('turbo:before-stream-render', this.boundHandleTurboStream)
    this.cleanupProgressBar()
  }

  // Get effective total (matches if searching, otherwise total lines)
  getEffectiveTotal() {
    return this.totalMatches !== null ? this.totalMatches : this.totalLinesValue
  }

  // Update the virtual content height
  updateContentHeight() {
    const effectiveTotal = this.getEffectiveTotal()
    const totalHeight = effectiveTotal * this.lineHeightValue
    this.contentTarget.style.height = `${totalHeight}px`
  }

  // Main method: load content at a given percentage position
  async loadAtPercent(percent, updateScroll = true) {
    percent = Math.max(0, Math.min(100, percent))
    this.currentPercent = percent

    // Cancel any pending request
    if (this.pendingRequest) {
      this.pendingRequest.abort()
    }

    const controller = new AbortController()
    this.pendingRequest = controller

    try {
      const url = new URL(this.viewUrlValue, window.location.origin)
      url.searchParams.set('percent', percent)
      url.searchParams.set('count', this.viewportCountValue)
      if (this.currentQuery) {
        url.searchParams.set('q', this.currentQuery)
      }

      const response = await fetch(url, {
        signal: controller.signal,
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (!response.ok) throw new Error('Failed to fetch')

      const data = await response.json()

      // Update totals
      this.totalLinesValue = data.total
      if (data.is_search) {
        this.totalMatches = data.total_matches
      } else {
        this.totalMatches = null
      }

      // Update content height in case totals changed
      this.updateContentHeight()

      // Track loaded range for scroll detection
      this.loadedStartIndex = data.start_index
      this.loadedEndIndex = data.end_index

      // Render the lines
      this.renderLines(data.html, data.start_index)

      // Update UI
      this.updateProgressPosition(percent)
      this.updateStatusText()
      this.updateSearchCount()

      // Update scroll position if needed
      if (updateScroll) {
        const effectiveTotal = this.getEffectiveTotal()
        const targetScroll = (percent / 100) * effectiveTotal * this.lineHeightValue
        this.viewportTarget.scrollTop = targetScroll
      }

    } catch (error) {
      if (error.name !== 'AbortError') {
        console.error('Load error:', error)
      }
    } finally {
      if (this.pendingRequest === controller) {
        this.pendingRequest = null
      }
    }
  }

  // Render the HTML content
  renderLines(html, startIndex) {
    // Parse the HTML and wrap each line with positioning
    const tempDiv = document.createElement('div')
    tempDiv.innerHTML = html
    const lines = tempDiv.querySelectorAll('.log-line')

    const fragment = document.createDocumentFragment()
    lines.forEach((line, idx) => {
      const wrapper = document.createElement('div')
      wrapper.className = 'virtual-line'
      wrapper.style.position = 'absolute'
      wrapper.style.top = `${(startIndex + idx) * this.lineHeightValue}px`
      wrapper.style.left = '0'
      wrapper.style.right = '0'
      wrapper.appendChild(line)
      fragment.appendChild(wrapper)
    })

    this.linesContainerTarget.innerHTML = ''
    this.linesContainerTarget.appendChild(fragment)
  }

  // Handle native scroll (mousewheel)
  handleScroll() {
    if (this.isDragging) return

    const scrollTop = this.viewportTarget.scrollTop
    const effectiveTotal = this.getEffectiveTotal()
    if (effectiveTotal === 0) return

    const maxScroll = effectiveTotal * this.lineHeightValue
    const percent = (scrollTop / maxScroll) * 100

    // Always update status text and progress position while scrolling
    this.updateStatusText()
    this.updateProgressPosition(percent)

    // On live streaming pages, don't reload when at the bottom - new content comes via Turbo Streams
    // This preserves RCON responses that aren't in the log file
    if (this.hasStreamTargetValue) {
      const viewportHeight = this.viewportTarget.clientHeight
      const contentHeight = effectiveTotal * this.lineHeightValue
      const distanceFromBottom = contentHeight - (scrollTop + viewportHeight)
      if (distanceFromBottom < viewportHeight) {
        return
      }
    }

    // Calculate what line the user is viewing
    const currentLine = Math.floor(scrollTop / this.lineHeightValue)

    // Check if we're near the edges of loaded content
    const buffer = this.viewportCountValue / 4  // Reload when within 25% of edge
    const needsReload =
      currentLine < this.loadedStartIndex + buffer ||
      currentLine > this.loadedEndIndex - buffer

    if (needsReload) {
      this.loadAtPercent(percent, false)
    }
  }

  // Progress bar setup
  setupProgressBar() {
    if (!this.hasProgressContainerTarget) return

    this.boundProgressClick = this.handleProgressClick.bind(this)
    this.boundMarkerMousedown = this.handleMarkerMousedown.bind(this)
    this.boundMarkerMousemove = this.handleMarkerMousemove.bind(this)
    this.boundMarkerMouseup = this.handleMarkerMouseup.bind(this)
    this.boundProgressHover = this.handleProgressHover.bind(this)

    this.progressContainerTarget.addEventListener('click', this.boundProgressClick)
    this.progressContainerTarget.addEventListener('mousemove', this.boundProgressHover)

    if (this.hasProgressPositionTarget) {
      this.progressPositionTarget.addEventListener('mousedown', this.boundMarkerMousedown)
    }
  }

  cleanupProgressBar() {
    if (this.hasProgressContainerTarget) {
      this.progressContainerTarget.removeEventListener('click', this.boundProgressClick)
      this.progressContainerTarget.removeEventListener('mousemove', this.boundProgressHover)
    }
    document.removeEventListener('mousemove', this.boundMarkerMousemove)
    document.removeEventListener('mouseup', this.boundMarkerMouseup)
  }

  // Handle click on progress bar
  handleProgressClick(event) {
    if (event.target === this.progressPositionTarget) return

    const rect = this.progressContainerTarget.getBoundingClientRect()
    const percent = Math.max(0, Math.min(100, ((event.clientX - rect.left) / rect.width) * 100))

    this.loadAtPercent(percent)
  }

  // Handle progress bar hover
  handleProgressHover(event) {
    if (!this.hasProgressTooltipTarget || this.isDragging) return

    const rect = this.progressContainerTarget.getBoundingClientRect()
    const percent = ((event.clientX - rect.left) / rect.width) * 100
    const effectiveTotal = this.getEffectiveTotal()
    const targetIndex = Math.round((percent / 100) * effectiveTotal)
    const label = this.totalMatches !== null ? 'Match' : 'Line'

    this.progressTooltipTarget.style.left = `${percent}%`
    this.progressTooltipTarget.textContent = `${label} ${targetIndex}`
  }

  // Handle drag start
  handleMarkerMousedown(event) {
    event.preventDefault()
    this.isDragging = true
    this.progressPositionTarget.classList.add('dragging')
    this.progressContainerTarget.classList.add('dragging')

    document.addEventListener('mousemove', this.boundMarkerMousemove)
    document.addEventListener('mouseup', this.boundMarkerMouseup)
  }

  // Handle drag move - just update UI, don't fetch
  handleMarkerMousemove(event) {
    if (!this.isDragging) return

    const rect = this.progressContainerTarget.getBoundingClientRect()
    const percent = Math.max(0, Math.min(100, ((event.clientX - rect.left) / rect.width) * 100))

    // Update UI instantly
    this.progressPositionTarget.style.left = `${percent}%`
    this.dragTargetPercent = percent

    // Update tooltip and status
    const effectiveTotal = this.getEffectiveTotal()
    const targetIndex = Math.round((percent / 100) * effectiveTotal)
    const label = this.totalMatches !== null ? 'Match' : 'Line'

    if (this.hasProgressTooltipTarget) {
      this.progressTooltipTarget.style.left = `${percent}%`
      this.progressTooltipTarget.textContent = `${label} ${targetIndex}`
    }
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = `${label} ${Math.max(1, targetIndex)} of ${effectiveTotal}`
    }

    // Scroll viewport instantly
    const targetScroll = (percent / 100) * effectiveTotal * this.lineHeightValue
    this.viewportTarget.scrollTop = targetScroll
  }

  // Handle drag end - now fetch the content
  handleMarkerMouseup() {
    const percent = this.dragTargetPercent || 0

    this.isDragging = false
    this.progressPositionTarget.classList.remove('dragging')
    this.progressContainerTarget.classList.remove('dragging')

    document.removeEventListener('mousemove', this.boundMarkerMousemove)
    document.removeEventListener('mouseup', this.boundMarkerMouseup)

    // Now load the content
    this.loadAtPercent(percent, false)
  }

  // Update progress position marker
  updateProgressPosition(percent) {
    if (this.hasProgressPositionTarget) {
      this.progressPositionTarget.style.left = `${percent}%`
    }
  }

  // Update status text based on scroll position
  updateStatusText() {
    if (!this.hasStatusTextTarget) return

    const effectiveTotal = this.getEffectiveTotal()
    if (effectiveTotal === 0) {
      this.statusTextTarget.textContent = this.totalMatches !== null ? 'No matches' : 'No lines'
      return
    }

    // Calculate current position based on scroll
    const scrollTop = this.viewportTarget.scrollTop
    const viewportHeight = this.viewportTarget.clientHeight
    const maxScroll = this.viewportTarget.scrollHeight - viewportHeight

    // If at the very bottom, show the last line
    // If at the very top, show line 1
    // Otherwise show the center
    let currentIndex
    if (scrollTop <= 0) {
      currentIndex = 1
    } else if (scrollTop >= maxScroll - 10) {
      currentIndex = effectiveTotal
    } else {
      const currentLine = Math.floor((scrollTop + viewportHeight / 2) / this.lineHeightValue)
      currentIndex = Math.max(1, Math.min(currentLine + 1, effectiveTotal))
    }

    const label = this.totalMatches !== null ? 'Match' : 'Line'
    this.statusTextTarget.textContent = `${label} ${currentIndex} of ${effectiveTotal}`
  }

  // Update search count display
  updateSearchCount() {
    if (!this.hasSearchCountTarget) return

    if (this.totalMatches !== null) {
      this.searchCountTarget.textContent = `${this.totalMatches} / ${this.totalLinesValue}`
    } else {
      this.searchCountTarget.textContent = ''
    }
  }

  // Keyboard shortcuts
  handleKeydown(event) {
    if (event.target.tagName === 'INPUT' || event.target.tagName === 'TEXTAREA') return

    switch (event.key) {
      case 'Home':
        event.preventDefault()
        this.scrollToTop()
        break
      case 'End':
        event.preventDefault()
        this.scrollToBottom()
        break
      case 'PageUp':
        event.preventDefault()
        this.scrollPageUp()
        break
      case 'PageDown':
        event.preventDefault()
        this.scrollPageDown()
        break
    }
  }

  scrollToTop() {
    this.loadAtPercent(0)
  }

  scrollToBottom() {
    this.loadAtPercent(100)
  }

  scrollPageUp() {
    const newPercent = Math.max(0, this.currentPercent - 10)
    this.loadAtPercent(newPercent)
  }

  scrollPageDown() {
    const newPercent = Math.min(100, this.currentPercent + 10)
    this.loadAtPercent(newPercent)
  }

  // Search
  search(event) {
    const query = event.target.value.trim()

    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }

    this.searchTimeout = setTimeout(() => {
      this.performSearch(query)
    }, 300)
  }

  performSearch(query) {
    this.currentQuery = query

    if (!query) {
      this.totalMatches = null
    }

    // Update the URL to reflect the search query
    this.updateUrl(query)

    // Load from start with new query
    this.loadAtPercent(0)
  }

  updateUrl(query) {
    const url = new URL(window.location.href)
    if (query) {
      url.searchParams.set('q', query)
    } else {
      url.searchParams.delete('q')
    }
    window.history.replaceState({}, '', url)
  }

  clearSearch() {
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ''
    }
    this.performSearch('')
  }

  // Handle click on log line to toggle raw view
  handleLogLineClick(event) {
    // Don't close if clicking on the raw content (allows text selection)
    if (event.target.closest('.log-raw')) return
    if (event.target.closest('a, button')) return

    const logLine = event.target.closest('.log-line')
    if (!logLine || !logLine.dataset.raw) return

    const isCurrentlyOpen = logLine.classList.contains('show-raw')

    // Close all other open raw lines
    this.linesContainerTarget.querySelectorAll('.log-line.show-raw').forEach(el => {
      el.classList.remove('show-raw')
    })

    // If this line wasn't open, open it
    if (!isCurrentlyOpen) {
      let rawEl = logLine.querySelector('.log-raw')
      if (!rawEl) {
        rawEl = document.createElement('div')
        rawEl.className = 'log-raw'
        rawEl.textContent = logLine.dataset.raw
        logLine.appendChild(rawEl)
      }
      logLine.classList.add('show-raw')
    }
  }

  // Handle Turbo Stream updates for live log
  handleTurboStreamAppend(event) {
    const stream = event.target
    if (!stream || stream.tagName !== 'TURBO-STREAM') return

    const targetId = stream.getAttribute('target')
    if (!this.hasStreamTargetValue || !targetId.includes(this.streamTargetValue)) return

    // Prevent default Turbo rendering - we handle it ourselves
    event.preventDefault()

    // If searching, just update the count - don't show unfiltered lines
    if (this.totalMatches !== null) {
      this.totalLinesValue++
      return
    }

    // Get the HTML content from the Turbo Stream template
    const template = stream.querySelector('template')
    if (!template) return

    const content = template.content.cloneNode(true)
    const logLine = content.querySelector('.log-line')
    if (!logLine) return

    // Check if we're near the bottom BEFORE updating
    // If user is viewing the last viewport worth of content, keep them at bottom
    const scrollTop = this.viewportTarget.scrollTop
    const viewportHeight = this.viewportTarget.clientHeight
    const currentContentHeight = this.getEffectiveTotal() * this.lineHeightValue
    const distanceFromBottom = currentContentHeight - (scrollTop + viewportHeight)
    const wasNearBottom = distanceFromBottom < viewportHeight

    // Create a positioned wrapper for the new line
    const wrapper = document.createElement('div')
    wrapper.className = 'virtual-line'
    wrapper.style.position = 'absolute'
    wrapper.style.top = `${this.totalLinesValue * this.lineHeightValue}px`
    wrapper.style.left = '0'
    wrapper.style.right = '0'
    wrapper.appendChild(logLine)

    // Append to the lines container
    this.linesContainerTarget.appendChild(wrapper)

    // Update totals and height
    this.totalLinesValue++
    this.loadedEndIndex = this.totalLinesValue
    this.updateContentHeight()

    // Auto-scroll to bottom if we were near the bottom
    if (wasNearBottom) {
      this.currentPercent = 100
      const effectiveTotal = this.getEffectiveTotal()
      const targetScroll = effectiveTotal * this.lineHeightValue
      this.viewportTarget.scrollTop = targetScroll
      this.updateProgressPosition(100)
    }

    this.updateStatusText()
  }

  // Utility
  debounce(func, wait) {
    let timeout
    return (...args) => {
      clearTimeout(timeout)
      timeout = setTimeout(() => func.apply(this, args), wait)
    }
  }
}
