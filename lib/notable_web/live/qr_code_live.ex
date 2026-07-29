defmodule NotableWeb.QrCodeLive do
  use NotableWeb, :live_view

  alias Notable.Qr
  alias NotableWeb.QrComponents

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
            <QrComponents.minimized_pill />
            <QrComponents.expanded_card qr={@qr} public_url={@public_url} />
          </div>
        </div>
      </div>
    </Layouts.app>
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
