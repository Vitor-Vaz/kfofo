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
    this.slides = Array.from(this.el.querySelectorAll("[data-slide]"))
    this.bullets = Array.from(this.el.querySelectorAll("[data-bullet]"))
    this.counter = this.el.querySelector("[data-counter]")
    this.total = this.slides.length

    if (this.total <= 1) return

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

      // Only swipe if horizontal motion is significantly larger than vertical motion
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

    this.slides.forEach((slide, i) => {
      if (i === this.index) {
        slide.classList.remove("hidden")
        slide.classList.add("block")
      } else {
        slide.classList.add("hidden")
        slide.classList.remove("block")
      }
    })

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

