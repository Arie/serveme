import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "searchInput", "searchCount", "searchForm", "searchFormQuery", "loadMoreSentinel", "statusBar", "statusText", "loadingOverlay", "progressBar", "progressContainer", "progressPosition", "progressTooltip", "topBtn", "bottomBtn", "clearBtn"]
  static values = {
    loadMoreUrl: String,
    debounce: { type: Number, default: 300 },
    liveMode: { type: Boolean, default: false },
    totalLines: { type: Number, default: 0 },
    matchedLines: { type: Number, default: 0 },
    loadedLines: { type: Number, default: 0 }
  }

  connect() {
    this.isLoadingMore = false
    this.setupInfiniteScroll()

    // Listen for turbo frame load to hide loading state and re-setup live filtering
    this.boundHandleFrameLoad = this.handleFrameLoad.bind(this)
    document.addEventListener('turbo:frame-load', this.boundHandleFrameLoad)

    // Setup keyboard shortcuts
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener('keydown', this.boundHandleKeydown)

    // Setup scroll position tracking
    this.boundHandleScroll = this.updateScrollPosition.bind(this)
    window.addEventListener('scroll', this.boundHandleScroll, { passive: true })

    // Setup draggable progress marker
    this.setupDraggableMarker()

    // Setup raw line toggle via event delegation
    this.boundHandleLogLineClick = this.handleLogLineClick.bind(this)
    if (this.hasContainerTarget) {
      this.containerTarget.addEventListener('click', this.boundHandleLogLineClick)
    }

    // In live mode, setup MutationObserver for live lines
    if (this.liveModeValue) {
      this.setupLiveFiltering()
    }
  }

  handleFrameLoad() {
    this.hideLoading()

    // Clear loading state from status text
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.classList.remove('loading')
    }

    // Re-setup live filtering after frame reload (container was replaced)
    if (this.liveModeValue && this.hasContainerTarget) {
      this.setupLiveFiltering()
    }

    // Re-attach click handler for raw line toggle (container was replaced)
    if (this.hasContainerTarget && this.boundHandleLogLineClick) {
      this.containerTarget.addEventListener('click', this.boundHandleLogLineClick)
    }

    // Update values from the new frame content (search may have changed matched/total)
    this.updateValuesFromFrame()

    // Re-setup draggable marker after frame reload (elements were replaced)
    this.cleanupDraggableMarker()
    this.setupDraggableMarker()

    // Re-observe the sentinel after frame reload (for infinite scroll)
    if (this.hasLoadMoreSentinelTarget && this.scrollObserver) {
      this.scrollObserver.observe(this.loadMoreSentinelTarget)
    }

    // If search was cleared, scroll to top and reset position
    if (this.pendingScrollToTop) {
      this.pendingScrollToTop = false
      window.scrollTo({ top: 0, behavior: 'auto' })
      if (this.hasProgressPositionTarget) {
        this.progressPositionTarget.style.left = '0%'
      }
      // Update status text to show line 1 (unless no results)
      if (!this.hasNoResults()) {
        const effectiveTotal = this.getEffectiveTotal()
        if (effectiveTotal > 0) {
          this.updateStatusText(1, effectiveTotal)
        }
      }
    }
  }

  // Read total/matched line counts from elements inside the turbo frame
  updateValuesFromFrame() {
    // Check search count span - format is "matched / total" when searching, empty otherwise
    if (this.hasSearchCountTarget) {
      const countText = this.searchCountTarget.textContent.trim()
      if (countText === '') {
        // No search active - matched should equal total
        // We'll read the total from status text below
      } else {
        // Parse "matched / total" format
        const countMatch = countText.match(/(\d+)\s*\/\s*(\d+)/)
        if (countMatch) {
          this.matchedLinesValue = parseInt(countMatch[1], 10)
          this.totalLinesValue = parseInt(countMatch[2], 10)
        }
      }
    }

    // Try to extract loaded count from sentinel text
    if (this.hasLoadMoreSentinelTarget) {
      const text = this.loadMoreSentinelTarget.querySelector('.log-load-more-text')?.textContent || ''
      const match = text.match(/\((\d+)\s*\/\s*(\d+)/)
      if (match) {
        const loaded = parseInt(match[1], 10)
        const total = parseInt(match[2], 10)
        this.loadedLinesValue = loaded

        // Check if this is a search result (contains "matches")
        if (text.includes('matches')) {
          this.matchedLinesValue = total
        } else {
          // No search active - total lines
          this.totalLinesValue = total
          this.matchedLinesValue = total
        }
        return
      }
    }

    // If no sentinel exists (all content loaded), count lines
    if (this.hasContainerTarget) {
      const loadedCount = this.containerTarget.querySelectorAll('.log-line').length
      this.loadedLinesValue = loadedCount
    }

    // Try to extract from status text
    if (this.hasStatusTextTarget) {
      const text = this.statusTextTarget.textContent || ''

      // Check for "No matching lines" (0 search results)
      if (text.includes('No matching')) {
        this.matchedLinesValue = 0
        this.loadedLinesValue = 0
        return
      }

      // Match "Match X of Y" or "Line X of Y"
      const statusMatch = text.match(/(Match|Line)\s+\d+\s+of\s+(\d+)/)
      if (statusMatch) {
        const total = parseInt(statusMatch[2], 10)
        if (statusMatch[1] === 'Match') {
          this.matchedLinesValue = total
        } else {
          // "Line X of Y" - no search active
          this.totalLinesValue = total
          this.matchedLinesValue = total // Ensure matched equals total
        }
      }
    }

    // Final safety check: if search input is empty, ensure matched = total
    if (this.hasSearchInputTarget && this.searchInputTarget.value.trim() === '') {
      if (this.totalLinesValue > 0 && this.matchedLinesValue !== this.totalLinesValue) {
        this.matchedLinesValue = this.totalLinesValue
      }
    }
  }

  disconnect() {
    if (this.scrollObserver) {
      this.scrollObserver.disconnect()
    }
    if (this.liveObserver) {
      this.liveObserver.disconnect()
    }
    document.removeEventListener('turbo:frame-load', this.boundHandleFrameLoad)
    document.removeEventListener('keydown', this.boundHandleKeydown)
    window.removeEventListener('scroll', this.boundHandleScroll)
    if (this.hasContainerTarget && this.boundHandleLogLineClick) {
      this.containerTarget.removeEventListener('click', this.boundHandleLogLineClick)
    }
    this.cleanupDraggableMarker()
  }

  // Handle click on log line to toggle raw view
  handleLogLineClick(event) {
    // Find the clicked log-line element
    const logLine = event.target.closest('.log-line')
    if (!logLine || !logLine.dataset.raw) return

    // Don't toggle if clicking on a link or button
    if (event.target.closest('a, button')) return

    // Toggle the raw line display
    let rawEl = logLine.querySelector('.log-raw')

    if (rawEl) {
      // Already exists, toggle visibility
      logLine.classList.toggle('show-raw')
    } else {
      // Create raw element lazily on first click
      rawEl = document.createElement('div')
      rawEl.className = 'log-raw'
      rawEl.textContent = logLine.dataset.raw
      logLine.appendChild(rawEl)
      // Force reflow before adding class for transition
      rawEl.offsetHeight
      logLine.classList.add('show-raw')
    }
  }

  showLoading() {
    if (this.hasLoadingOverlayTarget) {
      this.loadingOverlayTarget.classList.add('visible')
    }
  }

  hideLoading() {
    if (this.hasLoadingOverlayTarget) {
      this.loadingOverlayTarget.classList.remove('visible')
    }
  }

  setupInfiniteScroll() {
    this.scrollObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting && !this.isLoadingMore && !this.isDragging) {
          this.loadMore(entry.target)
        }
      })
    }, {
      root: null,
      rootMargin: '200px',
      threshold: 0
    })

    // Observe the current sentinel if it exists
    if (this.hasLoadMoreSentinelTarget) {
      this.scrollObserver.observe(this.loadMoreSentinelTarget)
    }
  }

  setupLiveFiltering() {
    // Disconnect any existing observer first (in case of frame reload)
    if (this.liveObserver) {
      this.liveObserver.disconnect()
    }

    // Watch for new log lines being added via Turbo Stream
    if (this.hasContainerTarget) {
      this.liveObserver = new MutationObserver((mutations) => {
        mutations.forEach(mutation => {
          mutation.addedNodes.forEach(node => {
            if (node.nodeType === Node.ELEMENT_NODE && node.classList.contains('log-line')) {
              this.applySearchToLine(node)
            }
          })
        })
      })

      this.liveObserver.observe(this.containerTarget, {
        childList: true,
        subtree: false
      })
    }
  }

  applySearchToLine(line) {
    // Apply search filter to individual line (for live incoming lines)
    const searchQuery = this.hasSearchInputTarget ? this.searchInputTarget.value.trim().toLowerCase() : ''

    if (searchQuery) {
      const lineText = line.textContent.toLowerCase()
      if (!lineText.includes(searchQuery)) {
        line.classList.add('search-hidden')
      } else {
        line.classList.remove('search-hidden')
      }
    } else {
      line.classList.remove('search-hidden')
    }
  }

  async loadMore(sentinel, chunkSize = null) {
    if (this.isLoadingMore || !this.hasLoadMoreUrlValue) return

    this.setLoadingState(true)
    const offset = sentinel.dataset.nextOffset
    const searchQuery = sentinel.dataset.searchQuery || ''

    try {
      // Use URL API to properly handle URLs that may already have query params
      const url = new URL(this.loadMoreUrlValue, window.location.origin)
      url.searchParams.set('offset', offset)
      if (searchQuery) {
        url.searchParams.set('q', searchQuery)
      }
      if (chunkSize) {
        url.searchParams.set('chunk_size', chunkSize)
      }

      const response = await fetch(url, {
        headers: {
          'Accept': 'text/html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (!response.ok) throw new Error('Failed to load more')

      const html = await response.text()

      // Remove the old sentinel
      if (this.scrollObserver) {
        this.scrollObserver.unobserve(sentinel)
      }
      sentinel.remove()

      // Append new content
      if (this.hasContainerTarget) {
        // Temporarily disconnect live observer during bulk insert to avoid per-line processing
        if (this.liveObserver) {
          this.liveObserver.disconnect()
        }

        this.containerTarget.insertAdjacentHTML('beforeend', html)

        // Reconnect live observer
        if (this.liveObserver && this.hasContainerTarget) {
          this.liveObserver.observe(this.containerTarget, { childList: true, subtree: false })
        }

        // Observe new sentinel if one exists
        if (this.hasLoadMoreSentinelTarget) {
          this.scrollObserver.observe(this.loadMoreSentinelTarget)
        }

        // Update status text
        this.updateStatusFromSentinel()
      }
    } catch (error) {
      console.error('Error loading more log lines:', error)
      sentinel.querySelector('.log-load-more-text').textContent = 'Error loading more. Scroll to retry.'
    } finally {
      this.setLoadingState(false)
    }
  }

  setLoadingState(loading) {
    this.isLoadingMore = loading
    // Don't clear visual loading state if we're in the middle of loadToTargetPercent
    if (loading || !this.loadingToTarget) {
      if (this.hasStatusTextTarget) {
        this.statusTextTarget.classList.toggle('loading', loading)
      }
    }
  }

  updateStatusFromSentinel() {
    if (this.hasLoadMoreSentinelTarget) {
      const sentinel = this.loadMoreSentinelTarget
      const text = sentinel.querySelector('.log-load-more-text')?.textContent || ''
      // Extract the counts from the loading text
      const match = text.match(/\((\d+)\s*\/\s*(\d+)/)
      if (match) {
        const loaded = parseInt(match[1], 10)
        const total = parseInt(match[2], 10)
        // Update progress bar and store values
        this.updateProgress(loaded, total)
      }
    } else {
      // No more to load - count the lines
      const lineCount = this.containerTarget.querySelectorAll('.log-line').length
      // Update progress bar to 100%
      this.updateProgress(lineCount, lineCount)
    }
    // Status text will be updated by updateScrollPosition on next scroll
  }

  search(event) {
    const value = event.target.value.trim()

    // Clear any pending debounce
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }

    // Debounce the server search
    this.searchTimeout = setTimeout(() => {
      this.performServerSearch(value)
    }, this.debounceValue)
  }

  performServerSearch(query) {
    if (this.hasSearchFormTarget) {
      if (this.hasSearchFormQueryTarget) {
        this.searchFormQueryTarget.value = query
      }
      // Reset progress bar to 0% while loading new results
      if (this.hasProgressBarTarget) {
        this.progressBarTarget.style.width = '0%'
      }
      if (this.hasProgressPositionTarget) {
        this.progressPositionTarget.style.left = '0%'
      }
      // Show loading indicator on status text
      if (this.hasStatusTextTarget) {
        this.statusTextTarget.textContent = 'Searching...'
        this.statusTextTarget.classList.add('loading')
      }

      // When search is cleared, reset matched/total to signal no search mode
      if (query === '') {
        // Pre-emptively set matched equal to total so isSearchMode() returns false
        // The actual values will be updated from frame content
        if (this.totalLinesValue > 0) {
          this.matchedLinesValue = this.totalLinesValue
        }
      }

      // Always scroll to top when search changes
      this.pendingScrollToTop = true

      this.showLoading()
      this.searchFormTarget.requestSubmit()
    }
  }

  clearSearch() {
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ''
      this.performServerSearch('')
    }
  }

  // Keyboard shortcuts
  handleKeydown(event) {
    // Don't trigger if typing in an input
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
    // Scroll to page top to include the search/rcon bar
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  async scrollToBottom() {
    // Don't scroll when search has no results
    if (this.hasNoResults()) return

    // If there's more content to load, load it all first
    if (this.hasLoadMoreSentinelTarget) {
      // Move marker to end position immediately
      if (this.hasProgressPositionTarget) {
        this.progressPositionTarget.style.left = '100%'
      }
      // Update status text to show target
      const effectiveTotal = this.getEffectiveTotal()
      if (effectiveTotal > 0) {
        this.updateStatusText(effectiveTotal, effectiveTotal)
      }
      await this.loadToTargetPercent(100)
    }

    // Scroll to the last log line
    if (this.hasContainerTarget) {
      const lastLine = this.containerTarget.querySelector('.log-line:last-of-type')
      if (lastLine) {
        lastLine.scrollIntoView({ behavior: 'smooth', block: 'end' })
      } else {
        this.containerTarget.scrollIntoView({ behavior: 'smooth', block: 'end' })
      }
    } else {
      window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' })
    }
  }

  scrollPageUp() {
    window.scrollBy({ top: -window.innerHeight * 0.8, behavior: 'smooth' })
  }

  scrollPageDown() {
    window.scrollBy({ top: window.innerHeight * 0.8, behavior: 'smooth' })
  }

  // Check if we're in search mode (matched lines differs from total)
  isSearchMode() {
    return this.matchedLinesValue > 0 && this.matchedLinesValue !== this.totalLinesValue
  }

  // Check if search is active but has no results
  hasNoResults() {
    return this.matchedLinesValue === 0 && this.hasSearchInputTarget && this.searchInputTarget.value.trim() !== ''
  }

  // Get effective total (matched lines in search mode, total otherwise)
  getEffectiveTotal() {
    return this.isSearchMode() ? this.matchedLinesValue : this.totalLinesValue
  }

  // Update progress bar
  updateProgress(loaded, total) {
    if (this.hasProgressBarTarget && total > 0) {
      const percent = (loaded / total * 100).toFixed(1)
      this.progressBarTarget.style.width = `${percent}%`
    }
    // Store values for scroll position updates
    // When loading more, we get the effective total from the sentinel text
    if (this.isSearchMode()) {
      this.matchedLinesValue = total
    } else {
      this.totalLinesValue = total
    }
    this.loadedLinesValue = loaded
  }

  // Update status text with current line number
  updateStatusText(currentLine, totalLines) {
    if (!this.hasStatusTextTarget || totalLines === 0) return
    const clampedLine = Math.max(1, Math.min(currentLine, totalLines))
    const label = this.isSearchMode() ? 'Match' : 'Line'
    this.statusTextTarget.textContent = `${label} ${clampedLine} of ${totalLines}`
  }

  // Update scroll position indicator
  updateScrollPosition() {
    if (this.isDragging || this.loadingToTarget) return // Don't update while dragging or loading to target
    if (this.hasNoResults()) return // Don't update when search has no results
    if (!this.hasContainerTarget) return

    const container = this.containerTarget
    const containerTop = container.offsetTop
    const containerHeight = container.scrollHeight
    const scrollTop = window.scrollY

    // Get the loaded percentage from the progress bar width
    const loadedPercent = this.hasProgressBarTarget ? (parseFloat(this.progressBarTarget.style.width) || 0) : 0

    // Calculate how far through the loaded container we've scrolled (0-100%)
    // Use top of viewport for line number calculation
    const scrollIntoContainer = Math.max(0, scrollTop - containerTop)
    const scrollThroughLoaded = Math.max(0, Math.min(100, (scrollIntoContainer / containerHeight) * 100))

    // Scale to stay within the green bar
    const positionPercent = (scrollThroughLoaded / 100) * loadedPercent

    if (this.hasProgressPositionTarget && this.hasProgressBarTarget) {
      this.progressPositionTarget.style.left = `${positionPercent}%`
    }

    // Update status text with current line/match number (1-indexed)
    const effectiveTotal = this.getEffectiveTotal()
    if (effectiveTotal > 0) {
      const currentLine = Math.max(1, Math.round((positionPercent / 100) * effectiveTotal))
      this.updateStatusText(currentLine, effectiveTotal)
    }
  }

  // Setup draggable marker
  setupDraggableMarker() {
    if (!this.hasProgressPositionTarget || !this.hasProgressContainerTarget) return

    this.isDragging = false

    this.boundMarkerMousedown = this.handleMarkerMousedown.bind(this)
    this.boundMarkerMousemove = this.handleMarkerMousemove.bind(this)
    this.boundMarkerMouseup = this.handleMarkerMouseup.bind(this)
    this.boundProgressBarClick = this.handleProgressBarClick.bind(this)
    this.boundProgressBarHover = this.handleProgressBarHover.bind(this)
    this.boundProgressBarLeave = this.handleProgressBarLeave.bind(this)

    this.progressPositionTarget.addEventListener('mousedown', this.boundMarkerMousedown)
    this.progressContainerTarget.addEventListener('click', this.boundProgressBarClick)
    this.progressContainerTarget.addEventListener('mousemove', this.boundProgressBarHover)
    this.progressContainerTarget.addEventListener('mouseleave', this.boundProgressBarLeave)
  }

  cleanupDraggableMarker() {
    if (this.boundMarkerMousedown && this.hasProgressPositionTarget) {
      this.progressPositionTarget.removeEventListener('mousedown', this.boundMarkerMousedown)
    }
    if (this.hasProgressContainerTarget) {
      if (this.boundProgressBarClick) {
        this.progressContainerTarget.removeEventListener('click', this.boundProgressBarClick)
      }
      if (this.boundProgressBarHover) {
        this.progressContainerTarget.removeEventListener('mousemove', this.boundProgressBarHover)
      }
      if (this.boundProgressBarLeave) {
        this.progressContainerTarget.removeEventListener('mouseleave', this.boundProgressBarLeave)
      }
    }
    document.removeEventListener('mousemove', this.boundMarkerMousemove)
    document.removeEventListener('mouseup', this.boundMarkerMouseup)
  }

  handleProgressBarClick(event) {
    // Ignore clicks on the marker itself (those are handled by drag)
    if (event.target === this.progressPositionTarget || this.progressPositionTarget.contains(event.target)) {
      return
    }
    // Don't allow interaction when search has no results
    if (this.hasNoResults()) return

    const containerRect = this.progressContainerTarget.getBoundingClientRect()
    const loadedPercent = parseFloat(this.progressBarTarget.style.width) || 0

    // Calculate click position as percentage
    const relativeX = event.clientX - containerRect.left
    const clickPercent = Math.max(0, Math.min(100, (relativeX / containerRect.width) * 100))

    // Update marker position
    this.progressPositionTarget.style.left = `${clickPercent}%`

    // Update status text
    const effectiveTotal = this.getEffectiveTotal()
    if (effectiveTotal > 0) {
      const targetLine = Math.round((clickPercent / 100) * effectiveTotal)
      this.updateStatusText(targetLine, effectiveTotal)
    }

    // If within loaded content, scroll there smoothly
    if (clickPercent <= loadedPercent && loadedPercent > 0) {
      this.scrollToPercent(clickPercent, true)
    } else if (this.hasLoadMoreSentinelTarget) {
      // Beyond loaded content - load to target
      this.loadToTargetPercent(clickPercent)
    }
  }

  handleProgressBarHover(event) {
    if (this.isDragging) return // Don't interfere with dragging
    if (!this.hasProgressTooltipTarget) return

    const containerRect = this.progressContainerTarget.getBoundingClientRect()
    const loadedPercent = parseFloat(this.progressBarTarget.style.width) || 0

    // Calculate hover position as percentage
    const relativeX = event.clientX - containerRect.left
    const hoverPercent = Math.max(0, Math.min(100, (relativeX / containerRect.width) * 100))

    // Position tooltip at hover location
    this.progressTooltipTarget.style.left = `${hoverPercent}%`

    const effectiveTotal = this.getEffectiveTotal()
    const label = this.isSearchMode() ? 'Match' : 'Line'

    // Update tooltip content based on position
    if (hoverPercent <= loadedPercent && loadedPercent > 0 && this.hasContainerTarget) {
      // Within loaded content - show timestamp
      const container = this.containerTarget
      const logLines = container.querySelectorAll('.log-line')
      if (logLines.length > 0) {
        const lineIndex = Math.floor((hoverPercent / loadedPercent) * logLines.length)
        const targetLine = logLines[Math.min(lineIndex, logLines.length - 1)]
        if (targetLine) {
          const timestamp = targetLine.querySelector('.log-timestamp')
          if (timestamp) {
            this.updateTooltipText(timestamp.textContent.trim())
          } else {
            this.updateTooltipText(`${label} ${lineIndex + 1}`)
          }
        }
      }
    } else {
      // Beyond loaded content - show target line/match
      if (effectiveTotal > 0) {
        const targetLine = Math.round((hoverPercent / 100) * effectiveTotal)
        this.updateTooltipText(`${label} ${targetLine}`)
      } else {
        this.updateTooltipText(`${Math.round(hoverPercent)}%`)
      }
    }
  }

  handleProgressBarLeave() {
    // Tooltip visibility is handled by CSS :hover
  }

  handleMarkerMousedown(event) {
    // Don't allow dragging when search has no results
    if (this.hasNoResults()) return
    event.preventDefault()
    this.isDragging = true
    this.progressPositionTarget.classList.add('dragging')
    this.progressContainerTarget.classList.add('dragging')

    document.addEventListener('mousemove', this.boundMarkerMousemove)
    document.addEventListener('mouseup', this.boundMarkerMouseup)
  }

  handleMarkerMousemove(event) {
    if (!this.isDragging || !this.hasProgressContainerTarget || !this.hasContainerTarget) return

    const containerRect = this.progressContainerTarget.getBoundingClientRect()
    const loadedPercent = parseFloat(this.progressBarTarget.style.width) || 0

    // Calculate position within the progress bar (0-100%) - allow full range
    const relativeX = event.clientX - containerRect.left
    const progressPercent = Math.max(0, Math.min(100, (relativeX / containerRect.width) * 100))

    // Update marker position
    this.progressPositionTarget.style.left = `${progressPercent}%`

    // Store target for potential loading
    this.dragTargetPercent = progressPercent

    const effectiveTotal = this.getEffectiveTotal()
    const label = this.isSearchMode() ? 'Match' : 'Line'

    // Calculate and update status text with target line number
    if (effectiveTotal > 0) {
      const targetLine = Math.round((progressPercent / 100) * effectiveTotal)
      this.updateStatusText(targetLine, effectiveTotal)
    }

    // Only scroll if within loaded content
    if (progressPercent <= loadedPercent && loadedPercent > 0) {
      const scrollThroughLoaded = progressPercent / loadedPercent

      const container = this.containerTarget
      const containerTop = container.offsetTop
      const viewportHeight = window.innerHeight

      // Calculate content height excluding sentinel
      const sentinel = container.querySelector('.log-load-more')
      const sentinelHeight = sentinel ? sentinel.offsetHeight : 0
      const contentHeight = container.scrollHeight - sentinelHeight

      const targetScrollInContainer = (scrollThroughLoaded * contentHeight)
      const targetScroll = containerTop + targetScrollInContainer - (viewportHeight / 2)

      // Cap scroll to not go past the content (before sentinel)
      const maxScroll = containerTop + contentHeight - viewportHeight
      const actualScroll = Math.max(0, Math.min(targetScroll, maxScroll))
      window.scrollTo({ top: actualScroll, behavior: 'auto' })

      // Calculate first visible line position (top of viewport)
      const firstVisiblePosition = Math.max(0, actualScroll - containerTop)
      const firstVisibleRatio = contentHeight > 0 ? firstVisiblePosition / contentHeight : 0

      // Update tooltip with timestamp of first visible line
      this.updateTooltipTimestamp(firstVisibleRatio)
      // Position tooltip at marker during drag
      if (this.hasProgressTooltipTarget) {
        this.progressTooltipTarget.style.left = `${progressPercent}%`
      }
    } else {
      // Beyond loaded content - show target line/match in tooltip
      if (effectiveTotal > 0) {
        const targetLine = Math.round((progressPercent / 100) * effectiveTotal)
        this.updateTooltipText(`${label} ${targetLine}`)
      } else {
        this.updateTooltipText(`${Math.round(progressPercent)}%`)
      }
      // Position tooltip at marker during drag
      if (this.hasProgressTooltipTarget) {
        this.progressTooltipTarget.style.left = `${progressPercent}%`
      }
    }
  }

  updateTooltipTimestamp(scrollThroughLoaded) {
    if (!this.hasProgressTooltipTarget || !this.hasContainerTarget) return

    const logLines = this.containerTarget.querySelectorAll('.log-line')
    if (logLines.length === 0) {
      this.updateTooltipText('')
      return
    }

    // Find the log line at this position
    const lineIndex = Math.floor(scrollThroughLoaded * logLines.length)
    const targetLine = logLines[Math.min(lineIndex, logLines.length - 1)]

    if (targetLine) {
      const timestamp = targetLine.querySelector('.log-timestamp')
      if (timestamp) {
        this.updateTooltipText(timestamp.textContent.trim())
      } else {
        // No timestamp, show line/match number
        const label = this.isSearchMode() ? 'Match' : 'Line'
        this.updateTooltipText(`${label} ${lineIndex + 1}`)
      }
    }
  }

  updateTooltipText(text) {
    if (this.hasProgressTooltipTarget) {
      this.progressTooltipTarget.textContent = text
    }
  }

  handleMarkerMouseup() {
    const targetPercent = this.dragTargetPercent
    const loadedPercent = parseFloat(this.progressBarTarget.style.width) || 0

    this.isDragging = false
    this.progressPositionTarget.classList.remove('dragging')
    this.progressContainerTarget.classList.remove('dragging')

    document.removeEventListener('mousemove', this.boundMarkerMousemove)
    document.removeEventListener('mouseup', this.boundMarkerMouseup)

    // If dragged beyond loaded content, start loading to reach target
    if (targetPercent > loadedPercent && this.hasLoadMoreSentinelTarget) {
      this.loadToTargetPercent(targetPercent)
    }
  }

  // Calculate adaptive chunk size based on distance to target
  getChunkSizeForDistance(distancePercent) {
    // Default chunk size
    const baseChunkSize = 1000
    // Maximum chunk size (must match MAX_CHUNK_SIZE in LogStreamingService)
    const maxChunkSize = 5000

    if (distancePercent <= 5) {
      // Close to target - use base chunk size for precision
      return baseChunkSize
    } else if (distancePercent <= 20) {
      // Medium distance - use larger chunks
      return Math.min(2000, maxChunkSize)
    } else {
      // Far - use maximum chunk size
      return maxChunkSize
    }
  }

  // Load content until we reach the target percentage
  async loadToTargetPercent(targetPercent) {
    this.loadingToTarget = true
    this.lockedTargetPercent = targetPercent

    // Show loading state on marker and status text
    if (this.hasProgressPositionTarget) {
      this.progressPositionTarget.classList.add('loading')
    }
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.classList.add('loading')
    }

    let reachedTarget = false
    while (this.hasLoadMoreSentinelTarget && !this.isLoadingMore) {
      const currentLoaded = parseFloat(this.progressBarTarget.style.width) || 0

      if (currentLoaded >= targetPercent) {
        // We've loaded enough, scroll to position (instant, not smooth)
        this.scrollToPercent(targetPercent, false)
        reachedTarget = true
        break
      }

      // Calculate distance remaining and get appropriate chunk size
      const distanceRemaining = targetPercent - currentLoaded
      const chunkSize = this.getChunkSizeForDistance(distanceRemaining)

      // Load more with adaptive chunk size
      await this.loadMoreAndWait(chunkSize)
    }

    // If we exited the loop without reaching target (e.g., all content loaded),
    // scroll to the target position anyway
    if (!reachedTarget) {
      this.scrollToPercent(targetPercent, false)
    }

    if (this.hasProgressPositionTarget) {
      this.progressPositionTarget.classList.remove('loading')
    }
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.classList.remove('loading')
    }
    this.loadingToTarget = false
    this.lockedTargetPercent = null
  }

  // Promise-based loadMore with optional chunk size
  loadMoreAndWait(chunkSize = null) {
    return new Promise((resolve) => {
      if (!this.hasLoadMoreSentinelTarget) {
        resolve()
        return
      }

      const sentinel = this.loadMoreSentinelTarget

      // Watch for sentinel removal (indicates load complete)
      const observer = new MutationObserver((_mutations, obs) => {
        if (!this.hasLoadMoreSentinelTarget || this.loadMoreSentinelTarget !== sentinel) {
          obs.disconnect()
          // Small delay to let DOM settle
          setTimeout(resolve, 50)
        }
      })

      observer.observe(this.containerTarget, { childList: true, subtree: true })

      // Trigger the load with optional chunk size
      this.loadMore(sentinel, chunkSize)

      // Timeout fallback
      setTimeout(() => {
        observer.disconnect()
        resolve()
      }, 5000)
    })
  }

  // Scroll to a specific percentage of the total content
  scrollToPercent(percent, smooth = true) {
    if (!this.hasContainerTarget) return

    const loadedPercent = parseFloat(this.progressBarTarget.style.width) || 0
    if (loadedPercent === 0) return

    const scrollThroughLoaded = Math.min(percent / loadedPercent, 1)

    const container = this.containerTarget
    const containerTop = container.offsetTop
    const containerHeight = container.scrollHeight

    const targetScrollInContainer = (scrollThroughLoaded * containerHeight)
    const targetScroll = containerTop + targetScrollInContainer

    window.scrollTo({ top: Math.max(0, targetScroll), behavior: smooth ? 'smooth' : 'auto' })
  }
}
