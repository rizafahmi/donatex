defmodule DonatexWeb.OverlayLive do
  use DonatexWeb, :live_view

  alias Donatex.Donations
  alias DonatexWeb.DonationPresenter

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")
    end

    queue =
      Donations.list_paid_unalerted_donations()
      |> Enum.map(&DonationPresenter.payload/1)
      |> :queue.from_list()

    {:ok,
     socket
     |> assign(:queue, queue)
     |> assign(:current, nil)
     |> start_next_alert()}
  end

  @impl Phoenix.LiveView
  def handle_info({:donation_paid, donation_payload}, socket) do
    {:noreply,
     socket
     |> update(:queue, &:queue.in(donation_payload, &1))
     |> start_next_alert()}
  end

  def handle_info({:dismiss_current, id}, socket) do
    socket =
      case socket.assigns.current do
        %{id: ^id} ->
          _ = Donations.mark_donation_alerted_by_id(id)

          socket
          |> assign(:current, nil)
          |> start_next_alert()

        _ ->
          socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} variant="overlay">
      <div class="obs-overlay-container">
        <%= if @current do %>
          <audio
            phx-hook="PlaySound"
            id={"audio-#{@current.id}"}
            src="/smb_stage_clear.wav"
            preload="auto"
            class="hidden"
          >
          </audio>
          <div class="obs-overlay-line">
            <div class="obs-overlay-box"></div>
            <div class="obs-overlay-main-text font-display">
              {@current.donor_name} memberikan
              <span class="obs-overlay-amount font-display">
                Rp {DonationPresenter.format_idr(@current.amount)}!!
              </span>
            </div>
            <div class="obs-overlay-sub-text">
              {@current.message}
            </div>
          </div>
        <% else %>
          <h1 class="hidden text-transparent" aria-hidden="true">Overlay</h1>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp start_next_alert(%{assigns: %{current: nil, queue: queue}} = socket) do
    case :queue.out(queue) do
      {{:value, next}, rest} ->
        Process.send_after(self(), {:dismiss_current, next.id}, 8_000)

        socket
        |> assign(:current, next)
        |> assign(:queue, rest)

      {:empty, _queue} ->
        socket
    end
  end

  defp start_next_alert(socket), do: socket
end
