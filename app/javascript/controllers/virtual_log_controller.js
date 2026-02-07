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
    "bottomBtn",          // Scroll to bottom button
    "delaySlider",        // Range input for delay
    "delayDisplay",       // Shows current delay value
    "bufferStatus",       // Shows buffered event count
    "highlightToggle",    // Checkbox for highlight-only mode
    "feedControls"        // Container for feed delay controls
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
    startAtEnd: { type: Boolean, default: false },  // Start at end of file (for RCON)
    delaySeconds: { type: Number, default: 0 },     // 0 = real-time
    highlightOnly: { type: Boolean, default: false } // Filter to important events only
  }

  connect() {
    this.currentQuery = this.initialQueryValue || ''
    this.totalMatches = null  // null means not searching
    this.isDragging = false
    this.currentPercent = 0
    this.pendingRequest = null
    this.loadedStartIndex = 0
    this.loadedEndIndex = 0
    this.tailing = this.startAtEndValue  // Track if we're following live updates
    this.isStreamingUpdate = false  // Flag to prevent scroll handler interference during streaming

    // Initialize delay buffer system
    this.eventBuffer = []
    this.delaySetAt = null         // Timestamp when delay was last set/increased
    this.bufferPrimed = false      // True once we've released at least one event
    this.startBufferProcessor()
    this.applyUrlParams()
    this.updateBufferStatus()

    // Set up the virtual scroll height
    this.updateContentHeight()

    // Set up scroll listener (for mousewheel scrolling)
    this.boundHandleScroll = this.debounce(this.handleScroll.bind(this), 50)
    this.viewportTarget.addEventListener('scroll', this.boundHandleScroll, { passive: true })

    // Separate immediate listener for tailing state (not debounced)
    this.boundUpdateTailingState = this.updateTailingState.bind(this)
    this.viewportTarget.addEventListener('scroll', this.boundUpdateTailingState, { passive: true })

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

    // Watch for Turbo Stream reconnection to catch up after disconnect
    this.setupReconnectObserver()

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
    this.viewportTarget.removeEventListener('scroll', this.boundUpdateTailingState)
    document.removeEventListener('keydown', this.boundHandleKeydown)
    this.linesContainerTarget.removeEventListener('click', this.boundHandleLogLineClick)
    document.removeEventListener('turbo:before-stream-render', this.boundHandleTurboStream)
    if (this.reconnectObserver) {
      this.reconnectObserver.disconnect()
    }
    this.cleanupProgressBar()

    // Clean up buffer processor
    if (this.bufferInterval) {
      clearInterval(this.bufferInterval)
    }
  }

  // Set up MutationObserver to detect Turbo Stream reconnection
  setupReconnectObserver() {
    if (!this.hasStreamTargetValue) return

    // Find the turbo-cable-stream-source element
    const streamSource = document.querySelector('turbo-cable-stream-source')
    if (!streamSource) return

    this.wasConnected = streamSource.hasAttribute('connected')

    this.reconnectObserver = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.type === 'attributes' && mutation.attributeName === 'connected') {
          const isConnected = streamSource.hasAttribute('connected')

          // Reconnected after being disconnected
          if (isConnected && !this.wasConnected) {
            this.handleReconnect()
          }
          this.wasConnected = isConnected
        }
      })
    })

    this.reconnectObserver.observe(streamSource, { attributes: true })
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

  // Immediately update tailing state on every scroll (not debounced)
  // This ensures we reliably detach from tailing when user scrolls up
  updateTailingState() {
    if (!this.hasStreamTargetValue) return

    const scrollTop = this.viewportTarget.scrollTop
    const viewportHeight = this.viewportTarget.clientHeight
    const scrollHeight = this.viewportTarget.scrollHeight

    // Use a small threshold: within 3 line heights of the bottom
    const threshold = this.lineHeightValue * 3
    const distanceFromBottom = scrollHeight - (scrollTop + viewportHeight)

    this.tailing = distanceFromBottom <= threshold
  }

  // Handle native scroll (mousewheel)
  handleScroll() {
    if (this.isDragging) return
    // Skip recalculation during streaming updates to prevent flickering
    if (this.isStreamingUpdate) return

    // In delay mode on streaming pages, force tailing - no scrolling away allowed
    if (this.hasStreamTargetValue && this.delaySecondsValue > 0) {
      this.tailing = true
      // Force scroll to bottom
      this.viewportTarget.scrollTop = this.viewportTarget.scrollHeight
      return
    }

    const scrollTop = this.viewportTarget.scrollTop
    const effectiveTotal = this.getEffectiveTotal()
    if (effectiveTotal === 0) return

    const maxScroll = effectiveTotal * this.lineHeightValue
    const percent = (scrollTop / maxScroll) * 100

    // When tailing on streaming pages, always show 100% to prevent nervous jumping
    if (this.hasStreamTargetValue && this.tailing) {
      this.updateProgressPosition(100)
      if (this.hasStatusTextTarget) {
        this.statusTextTarget.textContent = `Line ${effectiveTotal} of ${effectiveTotal}`
      }
      return
    }

    // Always update status text and progress position while scrolling
    this.updateStatusText()
    this.updateProgressPosition(percent)


    // For short logs where everything fits in viewport, no need to reload
    if (effectiveTotal <= this.viewportCountValue) {
      return
    }

    // Calculate what lines are visible (top and bottom of viewport)
    const viewportHeight = this.viewportTarget.clientHeight
    const topLine = Math.floor(scrollTop / this.lineHeightValue)
    const bottomLine = Math.floor((scrollTop + viewportHeight) / this.lineHeightValue)

    // Check if we're near the edges of loaded content
    const buffer = this.viewportCountValue / 4  // Reload when within 25% of edge
    const needsReload =
      topLine < this.loadedStartIndex + buffer ||
      bottomLine > this.loadedEndIndex - buffer

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
    // Disabled in delay mode on streaming pages - must stay tailing
    if (this.hasStreamTargetValue && this.delaySecondsValue > 0) return
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
    // Disabled in delay mode on streaming pages - must stay tailing
    if (this.hasStreamTargetValue && this.delaySecondsValue > 0) return

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
    // Disabled in delay mode on streaming pages - must stay tailing
    if (this.hasStreamTargetValue && this.delaySecondsValue > 0) return
    this.loadAtPercent(0)
  }

  scrollToBottom() {
    // In delay mode on streaming pages, just ensure we're tailing
    if (this.hasStreamTargetValue && this.delaySecondsValue > 0) {
      this.viewportTarget.scrollTop = this.viewportTarget.scrollHeight
      this.tailing = true
      return
    }

    this.loadAtPercent(100)
  }

  scrollPageUp() {
    // Disabled in delay mode on streaming pages - must stay tailing
    if (this.hasStreamTargetValue && this.delaySecondsValue > 0) return
    const newPercent = Math.max(0, this.currentPercent - 10)
    this.loadAtPercent(newPercent)
  }

  scrollPageDown() {
    // Disabled in delay mode on streaming pages - must stay tailing
    if (this.hasStreamTargetValue && this.delaySecondsValue > 0) return
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

      // On streaming pages, clearing search should go to end and resume tailing
      // (similar to reconnect behavior)
      if (this.hasStreamTargetValue) {
        this.tailing = true
        this.updateUrl(query)
        this.loadAtPercent(100)
        return
      }
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

  // Handle Turbo Stream reconnection - reload to catch up on missed lines
  handleReconnect() {
    if (!this.hasStreamTargetValue) return

    // Only reload if we were tailing (at the bottom)
    // Users scrolled up looking at history don't need a reload
    if (this.tailing) {
      // When delay is active on streaming pages, don't reload - just wait for buffered events
      // Reloading would bypass the buffer and show unbuffered content
      if (this.delaySecondsValue > 0) return
      this.loadAtPercent(100)
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

    // Get the HTML content from the Turbo Stream template
    const template = stream.querySelector('template')
    if (!template) return

    const content = template.content.cloneNode(true)
    const logLines = content.querySelectorAll('.log-line')
    if (logLines.length === 0) return

    // If searching, don't show unfiltered lines (but still count them)
    if (this.totalMatches !== null) {
      return
    }

    const now = Date.now()

    // Process each log line in the batch
    for (const logLine of logLines) {
      const eventType = logLine.dataset.eventType

      // Always buffer events (for seamless delay switching)
      const bufferedEvent = {
        html: logLine.outerHTML,
        receivedAt: now,
        eventType: eventType,
        rendered: false
      }
      this.eventBuffer.push(bufferedEvent)
    }

    // Eject events older than 90s (max delay) - they're no longer needed
    const maxAge = 90 * 1000
    while (this.eventBuffer.length > 0 && (now - this.eventBuffer[0].receivedAt) > maxAge) {
      this.eventBuffer.shift()
    }

    this.updateBufferStatus()
  }

  // Existing immediate render logic extracted to separate method
  renderImmediately(logLine, bufferedEvent = null) {
    // Set flag to prevent scroll handler interference during our updates
    this.isStreamingUpdate = true

    // Always update total line count and content height
    this.totalLinesValue++
    this.updateContentHeight()

    // Only render and track new lines if we're tailing
    // Otherwise there would be a gap between loaded content and streamed content
    if (!this.tailing) {
      // Just update the status to show there are more lines
      this.updateStatusText()
      this.isStreamingUpdate = false
      return
    }

    // Create a positioned wrapper for the new line
    const wrapper = document.createElement('div')
    wrapper.className = 'virtual-line'
    wrapper.style.position = 'absolute'
    wrapper.style.top = `${(this.totalLinesValue - 1) * this.lineHeightValue}px`
    wrapper.style.left = '0'
    wrapper.style.right = '0'
    wrapper.appendChild(logLine)

    // Store reference for un-rendering when delay increases
    if (bufferedEvent) {
      bufferedEvent.domElement = wrapper
    }

    // Append to the lines container
    this.linesContainerTarget.appendChild(wrapper)

    // Update loaded range to include the new line
    this.loadedEndIndex = this.totalLinesValue

    // Auto-scroll to bottom and update UI in the next frame to ensure DOM is updated
    this.currentPercent = 100
    const effectiveTotal = this.getEffectiveTotal()

    // Use requestAnimationFrame to ensure DOM has reflowed before updating scroll
    requestAnimationFrame(() => {
      const targetScroll = effectiveTotal * this.lineHeightValue
      this.viewportTarget.scrollTop = targetScroll
      this.updateProgressPosition(100)

      // Directly set status text to avoid calculation issues
      if (this.hasStatusTextTarget) {
        this.statusTextTarget.textContent = `Line ${effectiveTotal} of ${effectiveTotal}`
      }

      // Clear flag after a short delay to let any queued scroll events pass
      requestAnimationFrame(() => {
        this.isStreamingUpdate = false
      })
    })
  }

  // ==========================================
  // Feed Delay Buffer System
  // ==========================================

  // Start the buffer processor timer
  startBufferProcessor() {
    this.bufferInterval = setInterval(() => {
      this.processBuffer()
    }, 100) // Check every 100ms for smooth playback
  }

  // Process buffer and release events that have waited long enough
  processBuffer() {
    // Always update status first so countdown ticks even with empty buffer
    this.updateBufferStatus()

    if (this.eventBuffer.length === 0) return

    const now = Date.now()
    const delayMs = this.delaySecondsValue * 1000
    let renderedAny = false

    // Set flag to prevent scroll handler interference during our updates
    this.isStreamingUpdate = true

    // Don't shift events - keep them in buffer for potential un-rendering
    // Events are cleaned up by age (90s max) in handleTurboStreamAppend
    for (const event of this.eventBuffer) {
      const age = now - event.receivedAt
      if (age >= delayMs) {
        if (!event.rendered) {
          this.bufferPrimed = true  // Events are now flowing
          renderedAny = true
          // Only render if passes filter
          if (!this.highlightOnlyValue || this.isHighlightEvent(event.eventType)) {
            this.renderBufferedEvent(event)
          } else {
            event.rendered = true  // Mark as processed even if filtered out
          }
        }
      } else {
        break // Buffer is ordered chronologically, no need to check newer events
      }
    }

    // Clear flag after DOM has settled to let any queued scroll events pass
    if (renderedAny) {
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          this.isStreamingUpdate = false
        })
      })
    } else {
      this.isStreamingUpdate = false
    }
  }

  // Render a single buffered event
  renderBufferedEvent(bufferedEvent) {
    bufferedEvent.rendered = true
    this.totalLinesValue++
    this.updateContentHeight()

    if (!this.tailing) {
      this.updateStatusText()
      return
    }

    const wrapper = document.createElement('div')
    wrapper.className = 'virtual-line'
    wrapper.style.position = 'absolute'
    wrapper.style.top = `${(this.totalLinesValue - 1) * this.lineHeightValue}px`
    wrapper.style.left = '0'
    wrapper.style.right = '0'
    wrapper.innerHTML = bufferedEvent.html

    // Store reference for un-rendering when delay increases
    bufferedEvent.domElement = wrapper

    this.linesContainerTarget.appendChild(wrapper)
    this.loadedEndIndex = this.totalLinesValue

    // Auto-scroll if tailing
    requestAnimationFrame(() => {
      const targetScroll = this.totalLinesValue * this.lineHeightValue
      this.viewportTarget.scrollTop = targetScroll
      this.updateProgressPosition(100)
      this.updateStatusText()
    })
  }

  // Define which events are "highlight" events (big plays)
  isHighlightEvent(eventType) {
    const highlightEvents = [
      'medic_death',
      'medic_death_ex',
      'charge_deployed',
      'charge_ready',
      'lost_uber_advantage',

      'airshot',
      'airshot_heal',
      'domination',
      'revenge',

      // Objective events
      'point_capture',
      'capture_block',
      'round_win',
      'round_stalemate',
      'final_score',
      'match_end',

      'kill',
      'say'
    ]

    return highlightEvents.includes(eventType)
  }

  // Called when delay slider changes
  adjustDelay(event) {
    const oldDelay = this.delaySecondsValue
    const newDelay = parseInt(event.target.value, 10)
    this.delaySecondsValue = newDelay

    if (this.hasDelayDisplayTarget) {
      this.delayDisplayTarget.textContent = `${newDelay}s`
    }

    const now = Date.now()

    // Going to delay=0: flush buffer (catch up / peek mode)
    if (newDelay === 0 && oldDelay > 0) {
      this.flushBuffer()
      this.bufferPrimed = false
      this.delaySetAt = null
    }
    // Entering delay mode from live (0 → >0): clear and re-render from buffer
    else if (oldDelay === 0 && newDelay > 0) {
      // Clear everything and re-render from buffer for clean state
      this.reRenderFromBuffer()

      // Check if buffer has old enough events to be considered primed
      const oldestUnrendered = this.eventBuffer.find(e => !e.domElement)
      const hasOldEnoughEvents = oldestUnrendered &&
        (now - oldestUnrendered.receivedAt) >= newDelay * 1000

      if (hasOldEnoughEvents) {
        this.bufferPrimed = true
        this.delaySetAt = null
      } else if (!oldestUnrendered && this.eventBuffer.length > 0) {
        // All events are rendered, we're primed
        this.bufferPrimed = true
        this.delaySetAt = null
      } else {
        this.bufferPrimed = false
        this.delaySetAt = oldestUnrendered ? oldestUnrendered.receivedAt : now
      }
    }
    // Increasing delay (while already in delay mode): clear and re-render
    else if (newDelay > oldDelay) {
      // Clear and re-render for consistent positioning
      this.reRenderFromBuffer()

      // Check if buffer has unrendered events old enough
      const oldestUnrendered = this.eventBuffer.find(e => !e.domElement)
      const hasOldEnoughEvents = oldestUnrendered &&
        (now - oldestUnrendered.receivedAt) >= newDelay * 1000

      if (hasOldEnoughEvents) {
        this.bufferPrimed = true
        this.delaySetAt = null
      } else if (!oldestUnrendered && this.eventBuffer.length > 0) {
        // All events are rendered, we're primed
        this.bufferPrimed = true
        this.delaySetAt = null
      } else {
        this.bufferPrimed = false
        this.delaySetAt = oldestUnrendered ? oldestUnrendered.receivedAt : now
      }
    }
    // Decreasing delay (but not to 0): events will be rendered by processBuffer
    else if (newDelay > 0 && newDelay < oldDelay) {
      this.bufferPrimed = true
      this.delaySetAt = null
    }

    // Process any events that are now ready
    this.processBuffer()
    this.updateBufferStatus()
  }

  // Flush buffer - render all undisplayed events immediately (for catch up)
  flushBuffer() {
    for (const event of this.eventBuffer) {
      if (!event.rendered && (!this.highlightOnlyValue || this.isHighlightEvent(event.eventType))) {
        this.renderBufferedEvent(event)
      }
      event.rendered = true  // Mark as processed
    }
  }

  // Toggle highlight-only mode
  toggleHighlightOnly(event) {
    this.highlightOnlyValue = event.target.checked

    // Simplest approach: clear all visible events and re-render from buffer
    // This ensures correct ordering and positioning
    this.reRenderFromBuffer()
  }

  // Clear all visible events and re-render from buffer based on current filter settings
  reRenderFromBuffer() {
    // Remove all visible events from DOM and reset rendered state
    for (const event of this.eventBuffer) {
      if (event.domElement) {
        event.domElement.remove()
        event.domElement = null
      }
      event.rendered = false
    }

    // Clear container and reset count
    this.linesContainerTarget.innerHTML = ''
    this.totalLinesValue = 0

    // Re-render events that are old enough and pass the current filter
    const now = Date.now()
    const delayMs = this.delaySecondsValue * 1000

    for (const event of this.eventBuffer) {
      const age = now - event.receivedAt
      if (age >= delayMs) {
        if (!this.highlightOnlyValue || this.isHighlightEvent(event.eventType)) {
          this.renderBufferedEvent(event)
        }
      }
    }

    this.updateContentHeight()

    // Scroll to bottom since we're tailing in delay mode
    requestAnimationFrame(() => {
      this.viewportTarget.scrollTop = this.viewportTarget.scrollHeight
      this.updateStatusText()
    })
  }

  // Update buffer status display
  updateBufferStatus() {
    if (!this.hasBufferStatusTarget) return

    // Count only unprocessed events
    const count = this.eventBuffer.filter(e => !e.rendered).length
    const delaySeconds = this.delaySecondsValue
    const stvAhead = String(Math.max(0, 90 - delaySeconds)).padStart(2, '\u00A0')

    // Live mode (no delay)
    if (delaySeconds === 0) {
      this.bufferStatusTarget.textContent = `${count} buffered | ${stvAhead}s ahead of STV`
      this.bufferStatusTarget.classList.add('live')
      this.bufferStatusTarget.classList.remove('buffering')
      return
    }

    // Once events have started flowing, stay in ready state
    if (this.bufferPrimed) {
      this.bufferStatusTarget.textContent = `${count} buffered | ${stvAhead}s ahead of STV`
      this.bufferStatusTarget.classList.add('live')
      this.bufferStatusTarget.classList.remove('buffering')
      return
    }

    // Calculate how long we've been buffering (based on oldest undisplayed event)
    let fillSeconds
    const oldestUnrendered = this.eventBuffer.find(e => !e.domElement)
    if (oldestUnrendered) {
      // Use oldest unrendered event's age as the fill progress
      fillSeconds = Math.floor((Date.now() - oldestUnrendered.receivedAt) / 1000)
    } else if (this.delaySetAt) {
      // No unrendered events, use time since delay was set
      fillSeconds = Math.floor((Date.now() - this.delaySetAt) / 1000)
    } else {
      // Edge case: delay > 0 but delaySetAt not set, start tracking now
      this.delaySetAt = Date.now()
      fillSeconds = 0
    }

    // Check if buffer has filled enough
    if (fillSeconds >= delaySeconds) {
      // Buffer is ready (green)
      this.bufferStatusTarget.textContent = `${count} buffered | ${stvAhead}s ahead of STV`
      this.bufferStatusTarget.classList.add('live')
      this.bufferStatusTarget.classList.remove('buffering')
    } else {
      // Still filling buffer (yellow)
      const fillStr = String(fillSeconds).padStart(2, '\u00A0')
      const delayStr = String(delaySeconds).padStart(2, '\u00A0')
      this.bufferStatusTarget.textContent = `Buffering: ${fillStr}s / ${delayStr}s`
      this.bufferStatusTarget.classList.add('buffering')
      this.bufferStatusTarget.classList.remove('live')
    }
  }

  // Apply initial delay from URL or browser-restored form state
  applyUrlParams() {
    const urlParams = new URLSearchParams(window.location.search)
    const delayParam = urlParams.get('delay')

    if (delayParam) {
      // URL parameter takes priority
      const delay = parseInt(delayParam, 10)
      if (!isNaN(delay) && delay >= 0 && delay <= 90) {
        this.delaySecondsValue = delay
        if (delay > 0) {
          this.delaySetAt = Date.now()
        }
        if (this.hasDelaySliderTarget) {
          this.delaySliderTarget.value = delay
        }
        if (this.hasDelayDisplayTarget) {
          this.delayDisplayTarget.textContent = `${delay}s`
        }
      }
    } else if (this.hasDelaySliderTarget) {
      // Sync with browser-restored slider value
      const restoredDelay = parseInt(this.delaySliderTarget.value, 10)
      if (!isNaN(restoredDelay) && restoredDelay >= 0 && restoredDelay <= 90) {
        this.delaySecondsValue = restoredDelay
        if (restoredDelay > 0) {
          this.delaySetAt = Date.now()
        }
        if (this.hasDelayDisplayTarget) {
          this.delayDisplayTarget.textContent = `${restoredDelay}s`
        }
      }
    }

    const highlightParam = urlParams.get('highlights')
    if (highlightParam === 'true' || highlightParam === '1') {
      this.highlightOnlyValue = true
      if (this.hasHighlightToggleTarget) {
        this.highlightToggleTarget.checked = true
      }
    } else if (this.hasHighlightToggleTarget) {
      // Sync with browser-restored checkbox state
      this.highlightOnlyValue = this.highlightToggleTarget.checked
    }
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
