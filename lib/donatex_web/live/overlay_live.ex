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
      <div class="flex min-h-dvh items-center justify-center p-6">
        <%= if @current do %>
          <div class="w-full max-w-xl rounded-[2.25rem] border border-stroke/60 bg-surface/55 px-10 py-8 shadow-2xl shadow-black/50 backdrop-blur">
            <p class="text-xs font-semibold uppercase tracking-[0.25em] text-text-muted">
              Donation received
            </p>
            <p class="mt-4 font-display text-5xl font-semibold tracking-tight text-text">
              Rp {DonationPresenter.format_idr(@current.amount)}
            </p>
            <p class="mt-3 text-xl font-semibold text-text">{@current.donor_name}</p>
            <p
              :if={DonationPresenter.present_message?(@current.message)}
              class="mt-4 text-base text-text-muted"
            >
              "{@current.message}"
            </p>
          </div>
        <% else %>
          <h1 class="text-base font-semibold text-text-muted">Overlay</h1>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp start_next_alert(%{assigns: %{current: nil, queue: queue}} = socket) do
    case :queue.out(queue) do
      {{:value, next}, rest} ->
        Process.send_after(self(), {:dismiss_current, next.id}, 5_000)

        socket
        |> assign(:current, next)
        |> assign(:queue, rest)

      {:empty, _queue} ->
        socket
    end
  end

  defp start_next_alert(socket), do: socket
end
