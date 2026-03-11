import { Controller } from "@hotwired/stimulus"

const LEFT = [
  "australium", "blood", "collectors", "community", "decorated",
  "diamond", "festive", "genuine", "grizzled", "gold",
  "haunted", "horseless", "lethal", "rust", "self-made",
  "silver", "stock", "strange", "unique", "unusual", "vintage"
]

const RIGHT = [
  "alba", "admirable", "adysky", "agro", "artist", "arx", "ash", "auto",
  "banny", "beavern", "beta", "blaze", "bones", "botmode", "buud", "byte",
  "canfo", "captvk", "chris", "clockwork", "coleman", "connor", "cookye", "credu",
  "dave", "david", "darn", "dingo", "dmoule", "domo", "down",
  "eemes", "enigma", "enrith", "exfane", "extine",
  "fragga", "geel", "grumpykoi",
  "habib", "harbleu", "highfive", "hubida", "hugo",
  "ixy", "jan", "jay", "jon",
  "kaidus", "kaptain", "kermit", "kkaltuu", "klassy",
  "lange", "lansky", "lau", "laz", "logan", "lukas", "luke",
  "mak", "mana", "miggy", "mike", "mirelin",
  "numlocked", "ombrack", "opti",
  "paddie", "papi", "paulsen", "permzilla", "platinum", "polygon",
  "raymon", "reptile", "ruwin", "ryb",
  "samus", "seagull", "seeds", "seriouscat", "shade", "sheep", "sideshow",
  "sigafoo", "silentes", "silvo", "sim", "skeej", "skeez", "slemnish", "slin", "sorex", "squid",
  "star", "starkie",
  "tapley", "tek", "termo", "thalash", "toemas", "torden", "tragic", "turbotabs",
  "uncledane", "vis", "yeehaw", "yight", "yomps", "yuki",
  "war", "weqo", "zebbosai"
]

function randomElement(array) {
  return array[Math.floor(Math.random() * array.length)]
}

function generateFriendlyPassword() {
  return `${randomElement(LEFT)}-${randomElement(RIGHT)}-${Math.floor(Math.random() * 999)}`
}

export default class extends Controller {
  static targets = ["input", "button"]

  connect() {
    if (!this.hasButtonTarget) return

    const input = this.inputTarget
    const wrapper = document.createElement("div")
    wrapper.style.position = "relative"
    input.parentElement.insertBefore(wrapper, input)
    wrapper.appendChild(input)
    wrapper.appendChild(this.buttonTarget)
  }

  refresh() {
    this.inputTarget.value = generateFriendlyPassword()
  }
}
