import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.initializeGlobe()
    this.loadPlayerData()
    
    // Listen for Turbo Stream updates
    this.setupTurboStreamListeners()
  }

  disconnect() {
    if (this.globe) {
      this.globe._destructor()
    }
  }

  initializeGlobe() {
    const container = document.getElementById('globe-container')
    
    // Check if Globe is loaded
    if (typeof Globe === 'undefined') {
      console.error('Globe.gl not loaded yet, retrying...')
      setTimeout(() => this.initializeGlobe(), 100)
      return
    }
    
    // Create a stylized globe with gaming aesthetic
    this.globe = Globe()
      .backgroundColor('rgba(0,0,0,0)')
      .globeImageUrl('//unpkg.com/three-globe/example/img/earth-dark.jpg')
      .showAtmosphere(true)
      .atmosphereColor('rgba(255, 100, 50, 0.4)') // Orange glow like TF2
      .atmosphereAltitude(0.25)
      (container)
    
    // Apply custom material properties for a more stylized look
    if (typeof THREE !== 'undefined') {
      const globeMaterial = this.globe.globeMaterial()
      globeMaterial.emissive = new THREE.Color(0x1a1a1a)
      globeMaterial.emissiveIntensity = 0.1
      globeMaterial.shininess = 0.7
    }

    // Set initial view centered on Europe
    this.globe.pointOfView({ lat: 50, lng: 10, altitude: 2.5 })
    
    // Enable zoom and rotation
    this.globe.controls().enableZoom = true
    this.globe.controls().autoRotate = false

    // Hide loading indicator
    const loadingEl = document.getElementById('globe-loading')
    const statsEl = document.getElementById('globe-stats')
    if (loadingEl) loadingEl.style.display = 'none'
    if (statsEl) statsEl.style.display = 'block'
  }

  async loadPlayerData() {
    try {
      const response = await fetch('/players/globe.json')
      const data = await response.json()
      
      this.currentData = data // Store current data for disconnect notifications
      this.updateGlobeData(data.servers)
      this.updateStats(data.servers)
    } catch (error) {
      console.error('Error loading player data:', error)
    }
  }

  updateGlobeData(servers) {
    // Group servers by location (lat/lng)
    const locationGroups = {}
    servers.filter(s => s.latitude && s.longitude).forEach(server => {
      const key = `${server.latitude},${server.longitude}`
      if (!locationGroups[key]) {
        locationGroups[key] = {
          lat: server.latitude,
          lng: server.longitude,
          location: server.location,
          servers: [],
          totalPlayers: 0
        }
      }
      locationGroups[key].servers.push(server)
      locationGroups[key].totalPlayers += server.players.length
    })
    
    // Prepare server points - one per location
    const serverPoints = Object.values(locationGroups).map(group => {
      const activeServers = group.servers.filter(s => s.players.length > 0).length
      const label = group.servers.length > 1 
        ? `${group.location} - ${group.servers.length} servers (${activeServers} active, ${group.totalPlayers} players)`
        : `${group.servers[0].name} (${group.location}) - ${group.totalPlayers} players`
      
      return {
        lat: group.lat,
        lng: group.lng,
        label: label,
        color: group.totalPlayers > 0 ? '#ff0000' : '#ffff00',
        size: group.totalPlayers > 0 
          ? Math.max(0.2, Math.min(0.5, group.servers.length * 0.05 + group.totalPlayers * 0.01))
          : 0.15,
        altitude: 0.01,
        servers: group.servers
      }
    })

    // Prepare player-to-server arcs
    const arcs = []
    servers.forEach(server => {
      if (!server.latitude || !server.longitude) return
      
      server.players.forEach(player => {
        if (!player.latitude || !player.longitude) return
        
        // Color based on ping and loss
        let color
        if (player.loss >= 10) {
          color = 'rgba(255, 0, 0, 0.6)' // Red for high loss (10%+)
        } else if (player.loss >= 5) {
          color = 'rgba(255, 255, 0, 0.6)' // Yellow for medium loss (5-10%)
        } else if (player.ping >= 150) {
          color = 'rgba(255, 0, 0, 0.6)' // Red for high ping (150ms+)
        } else if (player.ping >= 100) {
          color = 'rgba(255, 255, 0, 0.6)' // Yellow for medium ping (100-150ms)
        } else {
          color = 'rgba(0, 255, 0, 0.6)' // Green for good connection (<100ms, <5% loss)
        }
        
        // Adjust arc height based on distance
        const distance = this.calculateDistance(player.latitude, player.longitude, server.latitude, server.longitude)
        const altitude = Math.min(0.4, distance / 20000)
        
        arcs.push({
          startLat: player.latitude,
          startLng: player.longitude,
          endLat: server.latitude,
          endLng: server.longitude,
          color: color,
          stroke: Math.max(0.2, 0.8 - player.loss * 0.05), // Much thinner lines
          altitude: altitude,
          label: `${player.name}: ${player.ping}ms (${player.loss}% loss)`
        })
      })
    })

    // Update globe points (servers)
    this.globe
      .pointsData(serverPoints)
      .pointLabel('label')
      .pointColor('color')
      .pointRadius('size')
      .pointAltitude('altitude')
      
    // Update globe arcs (player connections)
    this.globe
      .arcsData(arcs)
      .arcColor('color')
      .arcStroke('stroke')
      .arcAltitude('altitude')
      .arcLabel('label')
      .arcDashLength(0.5)
      .arcDashGap(0.1)
      .arcDashAnimateTime(1500)
  }

  updateStats(servers) {
    let totalPlayers = 0
    let activeServers = 0
    let totalServers = servers.length
    const countries = new Set()

    servers.forEach(server => {
      if (server.players.length > 0) {
        activeServers++
        server.players.forEach(player => {
          totalPlayers++
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
    updateElement('active-servers', totalServers)
    updateElement('total-countries', countries.size)
  }

  calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371 // Earth's radius in km
    const dLat = (lat2 - lat1) * Math.PI / 180
    const dLon = (lon2 - lon1) * Math.PI / 180
    const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
              Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
              Math.sin(dLon/2) * Math.sin(dLon/2)
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
    return R * c
  }
  
  setupTurboStreamListeners() {
    // Listen for player stats updates from ServerMetric
    document.addEventListener('turbo:before-stream-render', (event) => {
      const target = event.target.getAttribute('target')
      
      if (target === 'player_stats_update') {
        // Player statistics were updated - reload globe data
        this.loadPlayerData()
      }
    })
  }
}