defmodule NotableWeb.QrComponents do
  @moduledoc """
  Shared QR code rendering components used by the QR display pages.
  """

  use NotableWeb, :html

  alias Notable.Qr

  @doc """
  The minimized pill shown when the QR card is collapsed.
  """
  def minimized_pill(assigns) do
    ~H"""
    <div class="cta-minimized-pill" id="minimizedPill" title="Click to expand QR">
      <span class="cta-live-dot"></span>
      <span class="pill-text">Livestream Feedback</span>
      <span class="pill-badge">Scan QR 📱</span>
    </div>
    """
  end

  @doc """
  The expanded QR card: scannable QR panel plus the info side panel.
  """
  attr :qr, :map, required: true
  attr :public_url, :string, required: true

  def expanded_card(assigns) do
    ~H"""
    <div class="cta-card-expanded" id="expandedCard">
      <.qr_scannable_card qr={@qr} />
      <.info_side public_url={@public_url} />
    </div>
    """
  end

  @doc """
  The scannable QR panel: the animated canvas, plus a hidden unanimated SVG
  copy that the PNG download rasterises.

  The canvas carries its own `QrCanvas` hook rather than relying on a hook
  further up the page, so the QR animates on every page that embeds this
  component - `/qr` and `/qr-overlay` alike.
  """
  attr :qr, :map, required: true

  def qr_scannable_card(assigns) do
    assigns =
      assign(assigns,
        matrix: JSON.encode!(assigns.qr.matrix),
        palette: JSON.encode!(Qr.client_palette()),
        quiet_zone: Qr.quiet_zone()
      )

    ~H"""
    <div class="qr-isolated-panel">
      <div class="qr-scannable-card" id="qr-code">
        <canvas
          id="qr-canvas"
          class="qr-canvas"
          role="img"
          aria-label="QR code linking to the livestream feedback page"
          phx-hook="QrCanvas"
          phx-update="ignore"
          data-matrix={@matrix}
          data-size={@qr.size}
          data-quiet={@quiet_zone}
          data-palette={@palette}
        ></canvas>
      </div>
      <div class="qr-svg-hidden" id="qr-svg-hidden" aria-hidden="true" phx-no-format>
        {Phoenix.HTML.raw(@qr.svg)}
      </div>
    </div>
    """
  end

  attr :public_url, :string, required: true

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
end
