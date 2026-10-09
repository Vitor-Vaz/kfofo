// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let Hooks = {}

Hooks.CardCarousel = {
  mounted() {
    this.index = 0
    this.track = this.el.querySelector("[data-track]")
    this.slides = Array.from(this.el.querySelectorAll("[data-slide]"))
    this.bullets = Array.from(this.el.querySelectorAll("[data-bullet]"))
    this.counter = this.el.querySelector("[data-counter]")
    this.total = this.slides.length

    if (this.total <= 1 || !this.track) return

    this.prevBtn = this.el.querySelector("[data-action='prev']")
    this.nextBtn = this.el.querySelector("[data-action='next']")

    if (this.prevBtn) {
      this.prevBtn.addEventListener("click", (e) => {
        e.preventDefault()
        e.stopPropagation()
        this.goTo(this.index - 1)
      })
    }

    if (this.nextBtn) {
      this.nextBtn.addEventListener("click", (e) => {
        e.preventDefault()
        e.stopPropagation()
        this.goTo(this.index + 1)
      })
    }

    // Touch swipe gestures
    let startX = 0
    let startY = 0
    this.el.addEventListener("touchstart", (e) => {
      startX = e.touches[0].clientX
      startY = e.touches[0].clientY
    }, { passive: true })

    this.el.addEventListener("touchend", (e) => {
      let diffX = startX - e.changedTouches[0].clientX
      let diffY = startY - e.changedTouches[0].clientY

      if (Math.abs(diffX) > 40 && Math.abs(diffX) > Math.abs(diffY)) {
        if (diffX > 0) {
          this.goTo(this.index + 1)
        } else {
          this.goTo(this.index - 1)
        }
      }
    }, { passive: true })
  },

  goTo(idx) {
    if (idx < 0) idx = this.total - 1
    if (idx >= this.total) idx = 0
    this.index = idx

    if (this.track) {
      this.track.style.transform = `translateX(-${this.index * 100}%)`
    }

    if (this.bullets.length > 0) {
      let maxBullet = this.bullets.length - 1
      let activeBulletIdx = Math.min(this.index, maxBullet)
      this.bullets.forEach((bullet, i) => {
        if (i === activeBulletIdx) {
          bullet.classList.add("bg-white", "w-4")
          bullet.classList.remove("bg-white/50", "w-1.5")
        } else {
          bullet.classList.remove("bg-white", "w-4")
          bullet.classList.add("bg-white/50", "w-1.5")
        }
      })
    }

    if (this.counter) {
      this.counter.textContent = `${this.index + 1}/${this.total}`
    }
  }
}

Hooks.SearchPersistence = {
  mounted() {
    this.handleEvent("save_search", (params) => {
      try {
        localStorage.setItem("kfofo_search_filters", JSON.stringify(params))
      } catch (_e) {}
    })

    this.handleEvent("clear_saved_search", () => {
      try {
        localStorage.removeItem("kfofo_search_filters")
      } catch (_e) {}
    })

    const isHomeRoute = window.location.pathname === "/"
    if (isHomeRoute) {
      try {
        localStorage.removeItem("kfofo_search_filters")
      } catch (_e) {}
    }

    const isPropertiesRoute = window.location.pathname.startsWith("/properties")
    const urlParams = new URLSearchParams(window.location.search)
    const hasSearchParams = urlParams.has("location_query") || urlParams.has("city") || urlParams.has("state") || urlParams.has("type")

    if (isPropertiesRoute && !hasSearchParams) {
      try {
        const saved = localStorage.getItem("kfofo_search_filters")
        if (saved) {
          const parsed = JSON.parse(saved)
          if (parsed && typeof parsed === "object") {
            this.pushEvent("restore_search", parsed)
          }
        }
      } catch (_e) {}
    }
  }
}

Hooks.LocationAutocomplete = {
  mounted() {
    this.selectedIndex = -1
    this.debounceTimer = null
    this.input = this.el.querySelector("input[name='search[location_query]']")

    if (!this.input) return

    this.input.addEventListener("input", (e) => {
      clearTimeout(this.debounceTimer)
      const val = e.target.value
      this.debounceTimer = setTimeout(() => {
        this.pushEvent("suggest_locations", { value: val })
      }, 300)
    })

    this.input.addEventListener("keydown", (e) => {
      const items = Array.from(this.el.querySelectorAll("[data-prediction-item]"))
      if (items.length === 0) return

      if (e.key === "ArrowDown") {
        e.preventDefault()
        this.selectedIndex = (this.selectedIndex + 1) % items.length
        this.updateHighlight(items)
      } else if (e.key === "ArrowUp") {
        e.preventDefault()
        this.selectedIndex = (this.selectedIndex - 1 + items.length) % items.length
        this.updateHighlight(items)
      } else if ((e.key === "Enter" || e.key === "Tab") && this.selectedIndex >= 0) {
        const item = items[this.selectedIndex]
        if (item) {
          e.preventDefault()
          e.stopPropagation()
          clearTimeout(this.debounceTimer)
          const placeId = item.getAttribute("phx-value-place-id")
          const description = item.getAttribute("phx-value-description")

          if (placeId && description) {
            this.input.value = description
            this.pushEvent("select_location", { "place-id": placeId, "description": description })
          } else {
            item.click()
          }
          this.selectedIndex = -1
        }
      } else if (e.key === "Escape") {
        clearTimeout(this.debounceTimer)
        this.pushEvent("close_predictions", {})
        this.selectedIndex = -1
      }
    })

    this.bindPredictionClicks()

    document.addEventListener("click", (e) => {
      if (!this.el.contains(e.target)) {
        const dropdown = this.el.querySelector("[data-predictions-dropdown]")
        if (dropdown) {
          clearTimeout(this.debounceTimer)
          this.pushEvent("close_predictions", {})
          this.selectedIndex = -1
        }
      }
    })
  },

  updated() {
    const items = Array.from(this.el.querySelectorAll("[data-prediction-item]"))
    if (this.selectedIndex >= items.length) {
      this.selectedIndex = -1
    }
    if (this.selectedIndex >= 0 && items.length > 0) {
      this.updateHighlight(items)
    }
    this.bindPredictionClicks()
  },

  bindPredictionClicks() {
    const items = Array.from(this.el.querySelectorAll("[data-prediction-item]"))
    items.forEach((item, index) => {
      item.addEventListener("mouseenter", () => {
        this.selectedIndex = index
        this.updateHighlight(items)
      })
      item.addEventListener("click", (e) => {
        clearTimeout(this.debounceTimer)
        const placeId = item.getAttribute("phx-value-place-id")
        const description = item.getAttribute("phx-value-description")
        if (placeId && description) {
          e.preventDefault()
          e.stopPropagation()
          this.input.value = description
          this.pushEvent("select_location", { "place-id": placeId, "description": description })
          this.selectedIndex = -1
        }
      })
    })
  },

  updateHighlight(items) {
    items.forEach((item, i) => {
      if (i === this.selectedIndex) {
        item.classList.add("bg-orange-500/25", "border-orange-500", "!pl-5", "text-white")
        item.classList.remove("border-transparent", "pl-4")
        item.scrollIntoView({ block: "nearest", behavior: "smooth" })
      } else {
        item.classList.remove("bg-orange-500/25", "border-orange-500", "!pl-5", "text-white")
        item.classList.add("border-transparent", "pl-4")
      }
    })
  }
}

Hooks.FadeCounter = {
  updated() {
    const valueEl = this.el.querySelector("#counter-value")
    if (valueEl) {
      valueEl.classList.remove("animate-fade-in")
      void valueEl.offsetWidth
      valueEl.classList.add("animate-fade-in")
    }
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

