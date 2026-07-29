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
import {hooks as colocatedHooks} from "phoenix-colocated/notable"
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

// ===== Animated QR Canvas Hook =====
//
// Draws the QR matrix with a travelling data-flow wave, lightning-bolt data
// modules, pathway pulses and colour-coded finder patterns.
//
// Every colour it paints comes from the palette in `Notable.Qr`, handed over as
// a data attribute. That is deliberate: the scannability budget is enforced by
// Elixir tests against that palette, and animating only *between* palette
// colours keeps every intermediate frame inside the budget too (sRGB blends are
// never lighter than their lighter endpoint). Introducing a colour here that is
// not in the palette would escape that guarantee.
Hooks.QrCanvas = {
  mounted() {
    this._start()
    // ResizeObserver covers window resizes and the expand/minimize cycle
    // (`display: none` -> visible). A window listener alone misses re-expand,
    // and would also see clientWidth 0 while minimized.
    this._onResize = () => this._resize()
    if (typeof ResizeObserver !== "undefined") {
      this._ro = new ResizeObserver(this._onResize)
      this._ro.observe(this.el)
    } else {
      window.addEventListener("resize", this._onResize)
    }
  },

  destroyed() {
    if (this._raf) cancelAnimationFrame(this._raf)
    this._raf = null
    if (this._ro) {
      this._ro.disconnect()
      this._ro = null
    } else if (this._onResize) {
      window.removeEventListener("resize", this._onResize)
    }
  },

  _start() {
    const el = this.el

    try {
      this.matrix = JSON.parse(el.dataset.matrix || "[]")
      this.palette = JSON.parse(el.dataset.palette || "null")
    } catch (_e) {
      return
    }

    this.size = Number(el.dataset.size) || this.matrix.length
    this.quiet = Number(el.dataset.quiet) || 0
    if (!this.size || !this.matrix.length || !this.palette) return

    this.ctx = el.getContext("2d")
    if (!this.ctx) return

    this.boltPath = this._buildBoltPath()
    this.runs = this._buildPathways()
    this.reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches

    this._resize()

    if (this.reducedMotion) {
      this._draw(0)
      return
    }

    const tick = (now) => {
      this._draw(now)
      this._raf = requestAnimationFrame(tick)
    }
    this._raf = requestAnimationFrame(tick)
  },

  _resize() {
    if (!this.ctx) return
    // Always render at least 2x. At one device pixel per CSS pixel a module is
    // only ~8px wide and the bolt glyph degrades into speckle; supersampling
    // costs little and is what makes the bolts read as lightning.
    const dpr = Math.min(Math.max(window.devicePixelRatio || 1, 2), 3)
    // While the card is minimized it is `display: none`, so clientWidth is 0.
    // Keep the last good backing store rather than baking the 280 fallback into
    // a 320/260 card the moment it reappears.
    const cssSize = this.el.clientWidth
    if (!cssSize) return
    if (cssSize === this._cssSize && dpr === this._dpr) return

    this._cssSize = cssSize
    this._dpr = dpr
    this.el.width = Math.round(cssSize * dpr)
    this.el.height = Math.round(cssSize * dpr)
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    // Animated mode redraws on the next frame; reduced-motion has no raf loop.
    if (this.reducedMotion) this._draw(0)
    else if (!this._raf) this._draw(performance.now())
  },

  // The bolt glyph as a reusable Path2D in a unit box, scaled about the module
  // centre so `bolt_scale` means the same thing here as it does in Elixir.
  _buildBoltPath() {
    const path = new Path2D()
    const s = this.palette.bolt_scale

    this.palette.bolt_polygon.forEach(([x, y], i) => {
      const px = (x - 0.5) * s + 0.5
      const py = (y - 0.5) * s + 0.5
      if (i === 0) path.moveTo(px, py)
      else path.lineTo(px, py)
    })

    path.closePath()
    return path
  },

  // Horizontal runs of adjacent dark modules, which the pathway pulses travel
  // along. Runs of one or two modules read as flicker rather than flow, so
  // they are skipped.
  _buildPathways() {
    const runs = []

    for (let r = 0; r < this.size; r++) {
      let start = null

      for (let c = 0; c <= this.size; c++) {
        const on = c < this.size && this.matrix[r][c] === 1

        if (on && start === null) {
          start = c
        } else if (!on && start !== null) {
          if (c - start >= 3) runs.push({row: r, from: start, to: c - 1})
          start = null
        }
      }
    }

    return runs
  },

  _finderIndex(row, col) {
    const boxes = finderOrigins(this.size)

    for (let i = 0; i < boxes.length; i++) {
      const [fr, fc] = boxes[i]
      if (row >= fr && row <= fr + 6 && col >= fc && col <= fc + 6) return i
    }

    return null
  },

  // Picks a colour from a cycle at a continuous position, blending between
  // neighbours so transitions are smooth rather than stepped.
  _cycle(colours, position) {
    const n = colours.length
    const scaled = ((position % 1) + 1) % 1 * n
    const index = Math.floor(scaled)
    return blendHex(colours[index], colours[(index + 1) % n], scaled - index)
  },

  // Finder patterns are what a decoder locks onto, so they are drawn as three
  // whole rectangles - 7x7 ring, 5x5 light ring, 3x3 core - snapped to device
  // pixels. Filling them module by module leaves faint antialiased seams
  // across the block, which is both a visual defect and needless noise in the
  // one part of the code that has to be crisp. Only the hue is animated.
  _drawFinders(cell, time) {
    const {ctx, palette, size, quiet} = this
    const snap = (v) => Math.round(v * this._dpr) / this._dpr

    finderOrigins(size).forEach(([fr, fc], i) => {
      const breath = (Math.sin(time * 1.1 + i * 2.1) + 1) / 2
      const colour = blendHex(palette.finders[i], palette.module_cycle[0], breath * 0.5)

      const box = (rowOffset, colOffset, span, fill) => {
        const x = snap((fc + quiet + colOffset) * cell)
        const y = snap((fr + quiet + rowOffset) * cell)
        ctx.fillStyle = fill
        ctx.fillRect(x, y, snap((fc + quiet + colOffset + span) * cell) - x,
                     snap((fr + quiet + rowOffset + span) * cell) - y)
      }

      box(0, 0, 7, colour)
      box(1, 1, 5, palette.background)
      box(2, 2, 3, colour)
    })
  },

  _draw(t) {
    if (!this.ctx || !this._cssSize) return

    const {ctx, size, quiet, palette} = this
    const w = this._cssSize
    const span = size + quiet * 2
    const cell = w / span
    const time = this.reducedMotion ? 0 : t / 1000

    ctx.setTransform(this._dpr, 0, 0, this._dpr, 0, 0)
    ctx.globalCompositeOperation = "source-over"
    ctx.fillStyle = palette.background
    ctx.fillRect(0, 0, w, w)

    // Which pathway packets are lit right now, keyed "row:col".
    const lit = new Map()
    if (!this.reducedMotion) {
      this.runs.forEach((run, i) => {
        const length = run.to - run.from + 1
        const head = ((time * 3.2 + i * 0.37) % 2) * length
        for (let c = run.from; c <= run.to; c++) {
          const distance = Math.abs(c - run.from - head)
          if (distance < 1.6) lit.set(`${run.row}:${c}`, 1 - distance / 1.6)
        }
      })
    }

    for (let r = 0; r < size; r++) {
      for (let c = 0; c < size; c++) {
        if (!this.matrix[r][c]) continue

        // Finders are drawn whole, after this loop.
        if (this._finderIndex(r, c) !== null) continue

        const x = (c + quiet) * cell
        const y = (r + quiet) * cell

        // Diagonal data-flow wave travelling across the matrix.
        const wave = (Math.sin((r + c) * 0.34 - time * 1.9) + 1) / 2
        const pulse = lit.get(`${r}:${c}`) || 0

        const base = this._cycle(palette.module_cycle, wave * 0.5 + time * 0.05)
        ctx.fillStyle = pulse > 0 ? blendHex(base, palette.pulse, pulse) : base

        const inset = cell * 0.02
        const s = cell - inset * 2
        ctx.beginPath()
        if (typeof ctx.roundRect === "function") {
          ctx.roundRect(x + inset, y + inset, s, s, Math.min(s * 0.2, 3))
        } else {
          ctx.rect(x + inset, y + inset, s, s)
        }
        ctx.fill()

        // Lightning bolt, brightening as the wave and any pathway pulse pass.
        const boltPos = wave * 0.6 + time * 0.11 + pulse * 0.3
        ctx.fillStyle = this._cycle(palette.bolt_cycle, boltPos)
        ctx.save()
        ctx.translate(x, y)
        ctx.scale(cell, cell)
        ctx.fill(this.boltPath)
        ctx.restore()
      }
    }

    this._drawFinders(cell, time)

    if (this.reducedMotion) return

    // Scanner sweep. `multiply` can only darken, so the band tints the white
    // quiet areas without ever lifting a dark module toward the threshold.
    const sweepY = ((time * 0.28) % 1) * w
    const height = w * 0.13
    const gradient = ctx.createLinearGradient(0, sweepY - height, 0, sweepY + height)
    gradient.addColorStop(0, "#ffffff")
    gradient.addColorStop(0.42, palette.sweep)
    gradient.addColorStop(0.5, palette.sweep_core)
    gradient.addColorStop(0.58, palette.sweep)
    gradient.addColorStop(1, "#ffffff")

    ctx.globalCompositeOperation = palette.sweep_composite
    ctx.fillStyle = gradient
    ctx.fillRect(0, sweepY - height, w, height * 2)
    ctx.globalCompositeOperation = "source-over"
  }
}

// Top-left corners of the three finder patterns, matching
// `Notable.Qr.finder_positions/1`.
function finderOrigins(size) {
  return [[0, 0], [0, size - 7], [size - 7, 0]]
}

// Blends two `#rrggbb` colours in sRGB, matching `Notable.Qr.blend/3`.
// Returns `#rrggbb` (not `rgb(...)`) so callers can feed the result straight
// back in - pathway pulses blend the wave colour into `palette.pulse`.
function blendHex(from, to, amount) {
  const a = parseInt(from.slice(1), 16)
  const b = parseInt(to.slice(1), 16)
  const mix = (shift) => {
    const x = (a >> shift) & 255
    const y = (b >> shift) & 255
    return Math.round(x + (y - x) * amount)
  }
  const hex = (n) => n.toString(16).padStart(2, "0")
  return `#${hex(mix(16))}${hex(mix(8))}${hex(mix(0))}`
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

  // Renders the hidden, unanimated SVG to a PNG. The download deliberately
  // bypasses the canvas: what a user saves should be a plain, maximally
  // scannable QR, not a frame of the animation.
  _downloadPNG() {
    const svgEl = this.el.querySelector("#qr-svg-hidden svg")
    if (!svgEl) return

    const svgData = new XMLSerializer().serializeToString(svgEl)

    // A `blob:` URL would be blocked here: the page's CSP allows `img-src`
    // from 'self', `data:` and https only. Base64 keeps it inside `data:`.
    const encoded = window.btoa(unescape(encodeURIComponent(svgData)))
    const img = new Image()

    img.onload = () => {
      // The SVG carries explicit width/height, so fall back only if a browser
      // reports nothing rather than silently rasterising at the 150px default.
      const side = img.naturalWidth || 280
      const scale = 4
      const canvas = document.createElement("canvas")
      canvas.width = side * scale
      canvas.height = side * scale

      const ctx = canvas.getContext("2d")
      ctx.fillStyle = "#ffffff"
      ctx.fillRect(0, 0, canvas.width, canvas.height)
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height)

      const a = document.createElement("a")
      a.href = canvas.toDataURL("image/png")
      a.download = "qr-code.png"
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
    }

    img.src = "data:image/svg+xml;base64," + encoded
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

// ===== Flash Auto-Hide Hook =====
// Auto-dismisses toast/flash notices after a few seconds so they don't
// stick around indefinitely. The timer resets on `updated` so a second
// flash (e.g. another form submission) gets a fresh window. Connection
// error toasts opt out via `auto_hide={false}` and stay managed by
// `phx-connected` / `phx-disconnected`.
Hooks.FlashAutoHide = {
  mounted() {
    this._flashGeneration = this.el.dataset.flashGeneration
    this._scheduleClear()
  },
  updated() {
    const flashGeneration = this.el.dataset.flashGeneration

    if (flashGeneration !== this._flashGeneration) {
      this._flashGeneration = flashGeneration
      this._scheduleClear()
    }
  },
  destroyed() {
    this._clearTimer()
  },
  _scheduleClear() {
    this._clearTimer()
    const key = this.el.dataset.flashKey
    if (!key) return
    const flashGeneration = this._flashGeneration

    this._timer = setTimeout(() => {
      if (this.el.dataset.flashGeneration === flashGeneration) {
        this.pushEvent("lv:clear-flash", {key})
      }
    }, 5000)
  },
  _clearTimer() {
    if (this._timer) {
      clearTimeout(this._timer)
      this._timer = null
    }
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
