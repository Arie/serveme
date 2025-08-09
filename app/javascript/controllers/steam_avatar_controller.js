import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image"]
  static values = { 
    userId: Number,
    steamUid: String,
    size: String
  }

  connect() {
    this.loadAvatar()
  }

  async loadAvatar() {
    const img = this.imageTarget
    const userId = this.userIdValue
    const avatarSize = this.sizeValue || "medium"
    
    try {
      const response = await fetch(`/users/${userId}/steam_avatar?size=${avatarSize}`)
      const data = await response.json()
      
      if (data.avatar_url) {
        img.src = data.avatar_url
        img.onerror = () => {
          img.src = `https://avatars.steamstatic.com/fef49e7fa7e1997310d705b2a6158ff8dc1cdfeb_${avatarSize}.jpg`
          img.onerror = null
        }
      } else {
        this.fallbackToDefault(img, avatarSize)
      }
    } catch (error) {
      this.fallbackToDefault(img, avatarSize)
    }
  }

  fallbackToDefault(img, avatarSize) {
    img.src = `https://avatars.steamstatic.com/fef49e7fa7e1997310d705b2a6158ff8dc1cdfeb_${avatarSize}.jpg`
  }
}