defmodule DonatexWeb.QrOverlayLive do
  @moduledoc """
  A dedicated OBS display page that combines the scannable QR code with
  the flying emoji feedback overlay, so a streamer can show the QR and
  live reactions on a single screen.

  The QR encodes the public donor URL (`Donatex.Qr.public_url/0`); viewers
  scan it, submit free feedback on the donor page, and the chosen emoji
  floats up across this page in real time.
  """

  use DonatexWeb, :live_view

  alias Donatex.Qr
  alias DonatexWeb.OverlayComponents
  alias DonatexWeb.QrComponents

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:created")
    end

    url = Qr.public_url()
    qr = Qr.generate(url)

    {:ok,
     socket
     |> assign(:qr, qr)
     |> assign(:public_url, url)
     |> assign(:floats, %{})
     |> assign(:page_title, "QR Code & Feedback Overlay")
     |> assign(
       :meta_description,
       "OBS stream page showing the QR code and live emoji feedback reactions together."
     )
     |> assign(:meta_robots, "noindex, nofollow")
     |> assign(:canonical_url, url <> "/qr-overlay")}
  end

  @impl Phoenix.LiveView
  def handle_info({:donation_created, %{status: "sent"} = donation}, socket) do
    {:noreply, OverlayComponents.add_float(socket, donation)}
  end

  def handle_info({:donation_created, _donation}, socket), do: {:noreply, socket}

  def handle_info({:dismiss_float, id}, socket) do
    {:noreply, OverlayComponents.dismiss_float(socket, id)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} variant="overlay" show_header={false}>
      <div class="qr-page" id="qr-overlay-page">
        <div class="qr-page-inner">
          <QrComponents.qr_scannable_card qr={@qr} />
        </div>
        <div class="qr-overlay-floats" aria-hidden="true">
          <OverlayComponents.floats floats={@floats} />
        </div>
      </div>
    </Layouts.app>
    """
  end
end
