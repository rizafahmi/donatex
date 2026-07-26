defmodule DonatexWeb.QrCodeLive do
  use DonatexWeb, :live_view

  alias Donatex.Qr

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    url = Qr.public_url()
    qr = Qr.generate(url)

    {:ok,
     socket
     |> assign(:qr, qr)
     |> assign(:public_url, url)
     |> assign(:page_title, "QR Code")
     |> assign(:meta_description, "Scan the QR code to visit the livestream feedback page.")
     |> assign(:meta_robots, "noindex, nofollow")
     |> assign(:canonical_url, url <> "/qr")}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      flash_generations={@flash_generations}
      variant="overlay"
      show_header={false}
    >
      <div class="qr-page" id="qr-page" phx-hook="QrCode">
        <div class="qr-page-inner">
          <div class="cta-overlay-wrapper is-expanded" id="overlayWrapper">
            <.minimized_pill />
            <.expanded_card qr={@qr} public_url={@public_url} />
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp minimized_pill(assigns) do
    ~H"""
    <div class="cta-minimized-pill" id="minimizedPill" title="Click to expand QR">
      <span class="cta-live-dot"></span>
      <span class="pill-text">Livestream Feedback</span>
      <span class="pill-badge">Scan QR 📱</span>
    </div>
    """
  end

  defp expanded_card(assigns) do
    ~H"""
    <div class="cta-card-expanded" id="expandedCard">
      <div class="qr-isolated-panel">
        <div class="qr-scannable-card" id="qr-code">
          <canvas
            id="qr-canvas"
            class="qr-canvas"
            width="560"
            height="560"
            data-matrix={Jason.encode!(@qr.matrix)}
            data-size={@qr.size}
            aria-label="Animated QR code"
          >
          </canvas>
        </div>
        <div class="qr-svg-hidden" id="qr-svg-hidden" phx-no-format>
          {Phoenix.HTML.raw(@qr.svg)}
        </div>
      </div>
      <.info_side public_url={@public_url} />
    </div>
    """
  end

  defp info_side(assigns) do
    ~H"""
    <div class="cta-info-side">
      <div class="cta-header">
        <div class="cta-badge">
          <span class="cta-live-dot"></span>
          <span class="cta-badge-text">Livestream Feedback</span>
        </div>
        <h1 class="cta-title">
          Beri <span>Masukan</span> & Saran
        </h1>
      </div>
      <div class="cta-arrow-pointer-horizontal">
        <div class="cta-arrow-icon-wrapper">
          <svg
            width="18"
            height="18"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2.8"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <line x1="19" y1="12" x2="5" y2="12"></line>
            <polyline points="12 19 5 12 12 5"></polyline>
          </svg>
        </div>
        <span>Scan QR Code</span>
      </div>
      <div class="cta-url-badge" id="urlBadge">
        <svg
          width="18"
          height="18"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2.4"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"></path>
          <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"></path>
        </svg>
        <span>{@public_url |> String.replace_prefix("https://", "")}</span>
      </div>
      <div class="card-timer-bar" id="timerBar"></div>
      <div class="qr-actions">
        <button type="button" class="qr-btn qr-download-btn" id="qrDownloadBtn" phx-click="download">
          <svg
            width="20"
            height="20"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
            <polyline points="7 10 12 15 17 10"></polyline>
            <line x1="12" y1="15" x2="12" y2="3"></line>
          </svg>
          <span>Download PNG</span>
        </button>
        <button type="button" class="qr-btn qr-share-btn" id="qrShareBtn" phx-click="share">
          <svg
            width="20"
            height="20"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <circle cx="18" cy="5" r="3"></circle>
            <circle cx="6" cy="12" r="3"></circle>
            <circle cx="18" cy="19" r="3"></circle>
            <line x1="8.59" y1="13.51" x2="15.42" y2="17.49"></line>
            <line x1="15.41" y1="6.51" x2="8.59" y2="10.49"></line>
          </svg>
          <span>Share</span>
        </button>
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("download", _params, socket) do
    # PNG generation is handled client-side by the JS hook.
    # Push an event to the client to trigger the download.
    {:noreply, push_event(socket, "qr:download", %{})}
  end

  def handle_event("share", _params, socket) do
    {:noreply, push_event(socket, "qr:share", %{url: socket.assigns.public_url})}
  end
end
