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
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/donatex"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {}
import confetti from "../vendor/canvas-confetti"

Hooks.PlaySound = {
  mounted() {
    setTimeout(() => {
      // Play sound
      this.el.play().catch(error => {
        if (error.name === "NotAllowedError") {
          console.warn(
            "🔈 Autoplay blocked by browser. This is expected in Chrome/Safari during local testing.\n" +
            "👉 Click anywhere on the overlay page to allow sound, then replay the alert.\n" +
            "ℹ️ Note: OBS Browser Sources bypass this restriction automatically."
          )
        } else {
          console.error("Audio playback failed:", error)
        }
      })

      // Fire confetti celebration
      const duration = 4000;
      const end = Date.now() + duration;

      (function frame() {
        // Accents colors matching oklch(75% 0.14 165) ~ #10b981 green-ish and oklch(75% 0.14 65) ~ #eab308 orange/yellow-ish
        confetti({
          particleCount: 5,
          angle: 60,
          spread: 55,
          origin: { x: 0, y: 0.8 },
          colors: ['#79bd65', '#ea3d54', '#ee7b2a', '#ffffff']
        });
        confetti({
          particleCount: 5,
          angle: 120,
          spread: 55,
          origin: { x: 1, y: 0.8 },
          colors: ['#79bd65', '#ea3d54', '#ee7b2a', '#ffffff']
        });

        if (Date.now() < end) {
          requestAnimationFrame(frame);
        }
      }());
    }, 1500)
  }
}

// ===== QR Code Page Hook =====
Hooks.QrCode = {
  mounted() {
    this._initExpandMinimize()

    this.handleEvent("qr:download", () => this._downloadPNG())
    this.handleEvent("qr:share", ({url}) => this._share(url))
  },

  destroyed() {
    if (this._expandTimer) clearTimeout(this._expandTimer)
    if (this._minimizeTimer) clearTimeout(this._minimizeTimer)
  },

  _initExpandMinimize() {
    const wrapper = this.el.querySelector("#overlayWrapper")
    if (!wrapper) return

    const pill = this.el.querySelector("#minimizedPill")
    if (pill) {
      pill.addEventListener("click", () => {
        wrapper.classList.remove("is-minimized")
        wrapper.classList.add("is-expanded")
      })
    }

    // Auto-cycle: expanded for 3 min, minimized for 15s
    const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    if (prefersReducedMotion) return

    const EXPANDED_MS = 180000
    const MINIMIZED_MS = 15000
    let isPaused = false

    const minimize = () => {
      if (isPaused) return
      wrapper.classList.remove("is-expanded")
      wrapper.classList.add("is-minimized")
      this._stopTimerBar()
      this._minimizeTimer = setTimeout(expand, MINIMIZED_MS)
    }

    const expand = () => {
      if (isPaused) return
      wrapper.classList.remove("is-minimized")
      wrapper.classList.add("is-expanded")
      this._startTimerBar(EXPANDED_MS)
      this._expandTimer = setTimeout(minimize, EXPANDED_MS)
    }

    this._startTimerBar(EXPANDED_MS)
    this._expandTimer = setTimeout(minimize, EXPANDED_MS)

    // Pause on hover
    wrapper.addEventListener("mouseenter", () => {
      isPaused = true
      if (this._expandTimer) { clearTimeout(this._expandTimer); this._expandTimer = null }
      if (this._minimizeTimer) { clearTimeout(this._minimizeTimer); this._minimizeTimer = null }
      this._stopTimerBar()
    })
    wrapper.addEventListener("mouseleave", () => {
      isPaused = false
      if (wrapper.classList.contains("is-expanded")) {
        this._startTimerBar(EXPANDED_MS)
        this._expandTimer = setTimeout(minimize, EXPANDED_MS)
      } else {
        this._minimizeTimer = setTimeout(expand, MINIMIZED_MS)
      }
    })
  },

  _startTimerBar(durationMs) {
    const timerBar = this.el.querySelector("#timerBar")
    if (!timerBar) return
    timerBar.style.animation = "none"
    void timerBar.offsetWidth
    timerBar.style.animation = `qr-timer-drain ${durationMs}ms linear forwards`
  },

  _stopTimerBar() {
    const timerBar = this.el.querySelector("#timerBar")
    if (timerBar) timerBar.style.animation = "none"
  },

  _downloadPNG() {
    const svgEl = this.el.querySelector("#qr-svg-hidden svg")
    if (!svgEl) return

    const svgData = new XMLSerializer().serializeToString(svgEl)
    const svgBlob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" })
    const url = URL.createObjectURL(svgBlob)

    const img = new Image()
    img.onload = () => {
      const canvas = document.createElement("canvas")
      const scale = 4
      canvas.width = img.width * scale
      canvas.height = img.height * scale
      const ctx = canvas.getContext("2d")
      ctx.fillStyle = "#ffffff"
      ctx.fillRect(0, 0, canvas.width, canvas.height)
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height)
      URL.revokeObjectURL(url)

      canvas.toBlob((blob) => {
        const dlUrl = URL.createObjectURL(blob)
        const a = document.createElement("a")
        a.href = dlUrl
        a.download = "qr-code.png"
        document.body.appendChild(a)
        a.click()
        document.body.removeChild(a)
        URL.revokeObjectURL(dlUrl)
      }, "image/png")
    }
    img.src = url
  },

  _share(url) {
    if (navigator.share) {
      navigator.share({ title: "Livestream Feedback", url: url }).catch(() => {})
    } else {
      // Fallback: copy to clipboard
      navigator.clipboard.writeText(url).then(() => {
        this._showToast("Link copied to clipboard!")
      }).catch(() => {
        this._showToast("Copy failed. URL: " + url)
      })
    }
  },

  _showToast(message) {
    const toast = document.createElement("div")
    toast.textContent = message
    toast.style.cssText = `
      position: fixed; bottom: 24px; left: 50%; transform: translateX(-50%);
      background: rgba(31, 29, 46, 0.92); color: #e0def4; padding: 12px 24px;
      border-radius: 9999px; border: 1px solid rgba(196, 167, 231, 0.4);
      font-size: 14px; font-weight: 600; z-index: 9999;
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
      animation: qr-cta-badge-float 3s ease-in-out infinite;
    `
    document.body.appendChild(toast)
    setTimeout(() => toast.remove(), 3000)
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
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

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
