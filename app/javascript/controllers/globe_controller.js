import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { region: String }

  connect() {
    this.currentArcs = new Map()
    this.pendingArcUpdates = new Map()
    this.updateTimer = null

    this.allRegions = [
      { name: 'eu', displayName: 'EU', url: 'https://serveme.tf', color: '#0066ff' },
      { name: 'na', displayName: 'NA', url: 'https://na.serveme.tf', color: '#ff6600' },
      { name: 'au', displayName: 'AU', url: 'https://au.serveme.tf', color: '#00ff66' },
      { name: 'sea', displayName: 'SEA', url: 'https://sea.serveme.tf', color: '#ff00ff' }
    ]

    this.currentRegion = this.regionValue || 'eu'

    this.initializeGlobe()
    this.loadPlayerData()

    this.setupTurboStreamListeners()
    this.startCrossRegionUpdates()
  }

  disconnect() {
    if (this.crossRegionInterval) {
      clearInterval(this.crossRegionInterval)
    }
    if (this.globe) {
      this.globe._destructor()
    }
  }

  initializeGlobe() {
    const container = document.getElementById('globe-container')

    if (typeof Globe === 'undefined') {
      console.error('Globe.gl not loaded yet, retrying...')
      setTimeout(() => this.initializeGlobe(), 100)
      return
    }

    this.globe = Globe()
      .backgroundColor('rgba(0,0,0,0)')
      .globeImageUrl('//unpkg.com/three-globe/example/img/earth-dark.jpg')
      .showAtmosphere(true)
      .atmosphereColor('rgba(63, 63, 150, 0.1)')
      .atmosphereAltitude(0.15)
      (container)

    if (typeof THREE !== 'undefined') {
      const globeMaterial = this.globe.globeMaterial()
      globeMaterial.emissive = new THREE.Color(0x1a1a1a)
      globeMaterial.emissiveIntensity = 0.1
      globeMaterial.shininess = 0.7
    }

    const regionViews = {
      'eu': { lat: 50, lng: 10, altitude: 2.5 },
      'na': { lat: 40, lng: -100, altitude: 3 },
      'au': { lat: -25, lng: 135, altitude: 3 },
      'sea': { lat: 5, lng: 115, altitude: 3 }
    }

    const region = this.regionValue || 'eu'
    const viewConfig = regionViews[region] || regionViews['eu']
    this.globe.pointOfView(viewConfig)

    this.globe.controls().enableZoom = true
    this.globe.controls().autoRotate = false

    const loadingEl = document.getElementById('globe-loading')
    const statsEl = document.getElementById('globe-stats')
    if (loadingEl) loadingEl.style.display = 'none'
    if (statsEl) statsEl.style.display = 'block'
  }

  async loadPlayerData(incremental = false) {
    try {
      const response = await fetch('/players/globe.json')
      const data = await response.json()

      this.localRegionData = data
      this.currentRegion = data.region || this.regionValue || 'eu'

      const allServers = this.mergeRegionData()

      if (incremental && this.globe) {
        this.updateArcsOnly(allServers)
      } else {
        this.updateGlobeData(allServers)
      }

      if (this.pendingArcUpdates.size > 0) {
        this.pendingArcUpdates.forEach((update, arcKey) => {
          if (update.action === 'add') {
            this.currentArcs.set(arcKey, update.arc)
          } else if (update.action === 'remove') {
            this.currentArcs.delete(arcKey)
          }
        })
      }

      this.updateStats(allServers)
    } catch (error) {
      console.error('Error loading player data:', error)
    }
  }

  updateGlobeData(servers) {
    const locationGroups = {}
    servers.filter(s => s.latitude && s.longitude).forEach(server => {
      const roundedLat = Math.round(server.latitude * 100) / 100
      const roundedLng = Math.round(server.longitude * 100) / 100
      const key = `${roundedLat},${roundedLng}`

      if (!locationGroups[key]) {
        locationGroups[key] = {
          lat: server.latitude,
          lng: server.longitude,
          location: server.location,
          servers: [],
          totalPlayers: 0,
          cities: new Set()
        }
      }
      locationGroups[key].servers.push(server)
      locationGroups[key].totalPlayers += server.players.length

      const cityMatch = server.location.match(/^([^,]+)/)
      if (cityMatch) {
        locationGroups[key].cities.add(cityMatch[1].trim())
      }
    })

    const serverPoints = Object.values(locationGroups).map(group => {
      const activeServers = group.servers.filter(s => s.players.length > 0).length
      const totalServers = group.servers.length

      const cityNames = Array.from(group.cities).join("/")
      const locationLabel = cityNames || group.location

      const regionColor = group.servers[0]?.regionColor || '#0066ff'
      const regionName = group.servers[0]?.region ? this.getRegionDisplayName(group.servers[0].region) : ''
      const regionPrefix = regionName ? `[${regionName}] ` : ''

      const label = group.servers.length > 1
        ? `${regionPrefix}${locationLabel} - ${activeServers}/${totalServers} servers in use (${group.totalPlayers} players)`
        : `${regionPrefix}${group.servers[0].name} (${group.servers[0].location}) - ${group.totalPlayers > 0 ? 'In use' : 'Available'} (${group.totalPlayers} players)`

      return {
        lat: group.lat,
        lng: group.lng,
        label: label,
        color: regionColor,
        size: 0.05,
        altitude: 0.01,
        servers: group.servers
      }
    })

    // Build new arcs with unique keys
    const newArcs = []
    const newArcKeys = new Set()

    servers.forEach(server => {
      if (!server.latitude || !server.longitude) return

      server.players.forEach(player => {
        if (!player.latitude || !player.longitude) return

        const arcKey = `${player.steam_uid}_${server.id}`
        newArcKeys.add(arcKey)

        let color
        if (player.loss >= 10 || player.ping >= 150) {
          color = 'rgba(255, 0, 0, 0.6)' // Red for high loss (10%+) OR high ping (150ms+)
        } else if (player.loss >= 5 || player.ping >= 100) {
          color = 'rgba(255, 255, 0, 0.6)' // Yellow for medium loss (5-10%) OR medium ping (100-150ms)
        } else {
          color = 'rgba(0, 255, 0, 0.6)' // Green for good connection (<100ms, <5% loss)
        }

        const distance = this.calculateDistance(player.latitude, player.longitude, server.latitude, server.longitude)
        const altitude = Math.min(0.4, distance / 20000)

        const arc = {
          id: arcKey,
          startLat: player.latitude,
          startLng: player.longitude,
          endLat: server.latitude,
          endLng: server.longitude,
          color: color,
          stroke: 0.05,
          altitude: altitude,
          // Data for tooltip
          playerCity: player.city_name,
          playerCountry: player.country_name,
          serverName: server.name,
          serverLocation: server.location,
          ping: player.ping,
          loss: player.loss,
          minutes_connected: player.minutes_connected,
          distance: distance,
          label: player.city_name
            ? `${player.city_name}, ${player.country_name || 'Unknown'}: ${player.ping}ms (${player.loss}% loss)`
            : `${player.country_name || 'Unknown'}: ${player.ping}ms (${player.loss}% loss)`
        }

        newArcs.push(arc)
        this.currentArcs.set(arcKey, arc)
      })
    })

    const arcsToRemove = []
    this.currentArcs.forEach((arc, key) => {
      if (!newArcKeys.has(key)) {
        arcsToRemove.push(key)
      }
    })

    if (arcsToRemove.length > 0) {
      const fadingArcs = [...newArcs]
      arcsToRemove.forEach(key => {
        const arc = this.currentArcs.get(key)
        fadingArcs.push({
          ...arc,
          color: 'rgba(255, 255, 255, 0.1)',
          stroke: 0.01
        })
      })

      this.globe.arcsData(fadingArcs)

      setTimeout(() => {
        arcsToRemove.forEach(key => this.currentArcs.delete(key))
        const allArcs = Array.from(this.currentArcs.values())
        this.updateArcs(allArcs)
      }, 500)
    } else {
      const allArcs = Array.from(this.currentArcs.values())
      this.updateArcs(allArcs)
    }

    this.globe
      .pointsData(serverPoints)
      .pointLabel('label')
      .pointColor('color')
      .pointRadius('size')
      .pointAltitude('altitude')
      .pointsTransitionDuration(0)
  }

  updateArcs(arcs) {
    this.globe
      .arcsData(arcs)
      .arcColor('color')
      .arcStroke('stroke')
      .arcAltitude('altitude')
      .arcLabel(arc => this.createArcTooltip(arc))
      .arcDashLength(0.5)
      .arcDashGap(0.1)
      .arcDashAnimateTime(1500)
      .onArcClick(arc => this.handleArcClick(arc))
      .onArcHover(arc => this.handleArcHover(arc))
  }

  createArcTooltip(arc) {
    if (!arc) return ''

    const qualityEmoji = arc.loss >= 10 || arc.ping >= 150 ? '🔴' :
                        arc.loss >= 5 || arc.ping >= 100 ? '🟡' : '🟢'

    const connectionTime = arc.minutes_connected ? `${arc.minutes_connected} min` : 'Just connected'

    // Localize distance based on region
    const distanceStr = this.formatDistance(arc.distance || 0)

    return `
      <div style="font-family: monospace; padding: 8px; min-width: 250px;">
        <strong style="color: #4CAF50;">Player → Server Connection</strong><br/>
        <hr style="margin: 4px 0; opacity: 0.3;"/>

        <strong>📍 Player:</strong><br/>
        ${arc.playerCity || arc.playerCountry || 'Unknown'}<br/>

        <strong>🖥️ Server:</strong><br/>
        ${arc.serverName}<br/>
        ${arc.serverLocation}<br/>

        <hr style="margin: 4px 0; opacity: 0.3;"/>

        <strong>📊 Connection:</strong><br/>
        ${qualityEmoji} Ping: ${arc.ping}ms<br/>
        ${qualityEmoji} Loss: ${arc.loss}%<br/>
        ⏱️ Time: ${connectionTime}<br/>
        📏 Distance: ${distanceStr}
      </div>
    `
  }

  formatDistance(distanceKm) {
    if (this.regionValue === 'na') {
      // Convert to miles for North America
      const miles = distanceKm * 0.621371
      return `${Math.round(miles)} mi`
    } else {
      // Use kilometers for everyone else
      return `${Math.round(distanceKm)} km`
    }
  }

  handleArcClick(arc) {
    if (!arc) return

    // Calculate midpoint between player and server
    const midLat = (arc.startLat + arc.endLat) / 2
    const midLng = (arc.startLng + arc.endLng) / 2

    // Calculate appropriate altitude based on distance
    const distance = this.calculateDistance(arc.startLat, arc.startLng, arc.endLat, arc.endLng)
    const altitude = Math.min(2.5, Math.max(0.5, distance / 5000))

    // Animate to focus on the connection
    this.globe.pointOfView({
      lat: midLat,
      lng: midLng,
      altitude: altitude
    }, 1000) // 1 second animation
  }

  handleArcHover(arc) {
    // You could add hover effects here, like temporarily increasing stroke width
    if (arc) {
      this.element.style.cursor = 'pointer'
    } else {
      this.element.style.cursor = 'default'
    }
  }

  updateArcsOnly(servers) {
    // Build new arcs with unique keys
    const newArcs = []
    const newArcKeys = new Set()

    servers.forEach(server => {
      if (!server.latitude || !server.longitude) return

      server.players.forEach(player => {
        if (!player.latitude || !player.longitude) return

        const arcKey = `${player.steam_uid}_${server.id}`
        newArcKeys.add(arcKey)

        let color
        if (player.loss >= 10 || player.ping >= 150) {
          color = 'rgba(255, 0, 0, 0.6)' // Red for high loss (10%+) OR high ping (150ms+)
        } else if (player.loss >= 5 || player.ping >= 100) {
          color = 'rgba(255, 255, 0, 0.6)' // Yellow for medium loss (5-10%) OR medium ping (100-150ms)
        } else {
          color = 'rgba(0, 255, 0, 0.6)' // Green for good connection (<100ms, <5% loss)
        }

        const distance = this.calculateDistance(player.latitude, player.longitude, server.latitude, server.longitude)
        const altitude = Math.min(0.4, distance / 20000)

        const arc = {
          id: arcKey,
          startLat: player.latitude,
          startLng: player.longitude,
          endLat: server.latitude,
          endLng: server.longitude,
          color: color,
          stroke: 0.05,
          altitude: altitude,
          // Data for tooltip
          playerCity: player.city_name,
          playerCountry: player.country_name,
          serverName: server.name,
          serverLocation: server.location,
          ping: player.ping,
          loss: player.loss,
          minutes_connected: player.minutes_connected,
          distance: distance,
          label: player.city_name
            ? `${player.city_name}, ${player.country_name || 'Unknown'}: ${player.ping}ms (${player.loss}% loss)`
            : `${player.country_name || 'Unknown'}: ${player.ping}ms (${player.loss}% loss)`
        }

        newArcs.push(arc)
        this.currentArcs.set(arcKey, arc)
      })
    })

    // Identify arcs to remove
    const arcsToRemove = []
    this.currentArcs.forEach((arc, key) => {
      if (!newArcKeys.has(key)) {
        arcsToRemove.push(key)
      }
    })

    // Handle arc removal with smooth transition
    if (arcsToRemove.length > 0) {
      const fadingArcs = [...newArcs]
      arcsToRemove.forEach(key => {
        const arc = this.currentArcs.get(key)
        fadingArcs.push({
          ...arc,
          color: 'rgba(255, 255, 255, 0.1)',
          stroke: 0.01
        })
      })

      this.globe.arcsData(fadingArcs)

      setTimeout(() => {
        arcsToRemove.forEach(key => this.currentArcs.delete(key))
        const allArcs = Array.from(this.currentArcs.values())
        this.updateArcs(allArcs)
      }, 500)
    } else {
      const allArcs = Array.from(this.currentArcs.values())
      this.updateArcs(allArcs)
    }
  }

  updateFromTurboStream(data) {
    this.localRegionData = data

    if (this.globe) {
      const allServers = this.mergeRegionData()

      this.updateArcsOnly(allServers)
      this.updateStats(allServers)
    }
  }

  updateStats(servers) {
    let totalPlayers = 0
    let activeServers = 0
    let totalServers = servers.length
    const countries = new Set()
    const regionStats = {}

    this.allRegions.forEach(region => {
      regionStats[region.name] = { players: 0, activeServers: 0, totalServers: 0 }
    })

    servers.forEach(server => {
      const regionName = server.region || this.currentRegion

      if (regionStats[regionName]) {
        regionStats[regionName].totalServers++
      }

      if (server.players.length > 0) {
        activeServers++

        if (regionStats[regionName]) {
          regionStats[regionName].activeServers++
        }

        server.players.forEach(player => {
          totalPlayers++

          if (regionStats[regionName]) {
            regionStats[regionName].players++
          }

          if (player.country_code) {
            countries.add(player.country_code)
          }
        })
      }
    })

    const updateElement = (id, value) => {
      const el = document.getElementById(id)
      if (el) el.textContent = value
    }

    updateElement('total-players', totalPlayers)
    updateElement('active-servers', `${activeServers}/${totalServers}`)
    updateElement('total-countries', countries.size)

    this.updateRegionBreakdown(regionStats)
  }

  updateRegionBreakdown(regionStats) {
    let regionBreakdownEl = document.getElementById('region-breakdown')

    if (!regionBreakdownEl) {
      const statsEl = document.getElementById('globe-stats')
      if (statsEl) {
        const flexContainer = statsEl.querySelector('.d-flex.text-white')
        if (flexContainer) {
          const breakdownWrapper = document.createElement('div')
          breakdownWrapper.id = 'region-breakdown'
          breakdownWrapper.className = 'd-flex'
          flexContainer.appendChild(breakdownWrapper)
          regionBreakdownEl = breakdownWrapper
        }
      }
    }

    if (!regionBreakdownEl) return

    const html = this.allRegions.map(region => {
      const stats = regionStats[region.name]
      if (!stats || stats.totalServers === 0) return ''

      return `
        <div class="px-3 border-start border-secondary">
          <small class="text-muted d-block">
            <span style="color: ${region.color}; font-size: 1.2em;">●</span> ${region.displayName}
          </small>
          <span class="small">
            ${stats.players} players - ${stats.activeServers}/${stats.totalServers} servers
          </span>
        </div>
      `
    }).filter(Boolean).join('')

    regionBreakdownEl.innerHTML = html
  }

  calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371
    const dLat = (lat2 - lat1) * Math.PI / 180
    const dLon = (lon2 - lon1) * Math.PI / 180
    const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
              Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
              Math.sin(dLon/2) * Math.sin(dLon/2)
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
    return R * c
  }

  startCrossRegionUpdates() {
    this.otherRegionsData = {}

    this.fetchOtherRegions()

    this.crossRegionInterval = setInterval(() => {
      this.fetchOtherRegions()
    }, 60000)
  }

  async fetchOtherRegions() {
    const isLocalhost = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'

    const regionsToFetch = isLocalhost
      ? this.allRegions
      : this.allRegions.filter(r => r.name !== this.currentRegion)

    const fetchPromises = regionsToFetch.map(region =>
      this.fetchRegionData(region).catch(error => {
        console.warn(`Failed to fetch data from ${region.name}:`, error)
        return null
      })
    )

    const results = await Promise.all(fetchPromises)

    results.forEach((data, index) => {
      if (data) {
        const region = regionsToFetch[index]
        this.otherRegionsData[region.name] = data
      }
    })

    if (this.globe && this.localRegionData) {
      const allServers = this.mergeRegionData()
      this.updateGlobeData(allServers)
      this.updateStats(allServers)
    }
  }

  async fetchRegionData(region) {
    const response = await fetch(`${region.url}/players/globe.json`, {
      method: 'GET',
      mode: 'cors',
      cache: 'no-cache'
    })

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`)
    }

    return await response.json()
  }

  mergeRegionData() {
    const isLocalhost = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'

    const localServers = isLocalhost ? [] : (this.localRegionData?.servers || []).map(server => ({
      ...server,
      region: this.currentRegion,
      regionColor: this.getRegionColor(this.currentRegion)
    }))

    const otherServers = Object.entries(this.otherRegionsData).flatMap(([regionName, data]) => {
      const actualRegion = data?.region || regionName
      return (data?.servers || []).map(server => ({
        ...server,
        region: actualRegion,
        regionColor: this.getRegionColor(actualRegion)
      }))
    })

    return [...localServers, ...otherServers]
  }

  getRegionColor(regionName) {
    const region = this.allRegions.find(r => r.name === regionName)
    return region ? region.color : '#0066ff'
  }

  getRegionDisplayName(regionName) {
    const region = this.allRegions.find(r => r.name === regionName)
    return region ? region.displayName : regionName.toUpperCase()
  }

  setupTurboStreamListeners() {
    document.addEventListener('turbo:before-stream-render', (event) => {
      const target = event.target.getAttribute('target')

      if (target === 'player_stats_update') {
        // Extract globe data from the incoming stream
        const template = event.detail.newStream.querySelector('template')
        const content = template.content.querySelector('#player_stats_update')

        if (content && content.dataset.globeData) {
          const data = JSON.parse(content.dataset.globeData)
          this.updateFromTurboStream(data)
        }
      }
    })
  }

  addPlayerConnection(playerData) {
    const arcKey = `${playerData.steam_uid}_${playerData.server_id}`

    if (playerData.player_latitude && playerData.player_longitude) {
      const distance = this.calculateDistance(
        playerData.player_latitude,
        playerData.player_longitude,
        playerData.server_latitude,
        playerData.server_longitude
      )
      const altitude = Math.min(0.4, distance / 20000)

      const arc = {
        id: arcKey,
        startLat: playerData.player_latitude,
        startLng: playerData.player_longitude,
        endLat: playerData.server_latitude,
        endLng: playerData.server_longitude,
        color: 'rgba(128, 128, 128, 0.6)',
        stroke: 0.05,
        altitude: altitude,
        // Data for tooltip
        playerCity: playerData.city_name,
        playerCountry: playerData.country_name,
        serverName: playerData.server_name,
        serverLocation: playerData.server_location,
        ping: 0,
        loss: 0,
        minutes_connected: 0,
        distance: distance,
        label: playerData.city_name
          ? `${playerData.city_name}, ${playerData.country_name || 'Unknown'}: Connecting...`
          : `${playerData.country_name || 'Unknown'}: Connecting...`
      }

      this.pendingArcUpdates.set(arcKey, {
        action: 'add',
        arc,
        timestamp: Date.now()
      })
      this.scheduleUpdate()
    }
  }

  removePlayerConnection(steamUid, serverId) {
    const arcKey = `${steamUid}_${serverId}`

    this.pendingArcUpdates.set(arcKey, {
      action: 'remove',
      timestamp: Date.now()
    })
    this.scheduleUpdate()
  }

  scheduleUpdate() {
    if (this.updateTimer) {
      clearTimeout(this.updateTimer)
    }

    this.updateTimer = setTimeout(() => {
      this.processPendingUpdates()
    }, 100)
  }

  processPendingUpdates() {
    if (this.pendingArcUpdates.size === 0) return

    this.pendingArcUpdates.forEach((update, arcKey) => {
      if (update.action === 'add') {
        this.currentArcs.set(arcKey, update.arc)
      } else if (update.action === 'remove') {
        this.currentArcs.delete(arcKey)
      }
    })

    this.pendingArcUpdates.clear()
    this.updateTimer = null

    const currentArcs = Array.from(this.currentArcs.values())
    this.updateArcs(currentArcs)
  }
}
