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
     |> update(:queue, &(&1 ++ [donation_payload]))
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
    <Layouts.app flash={@flash}>
      <div class="flex min-h-[60vh] items-center justify-center">
        <%= if @current do %>
          <div class="rounded-3xl border border-base-300/70 bg-base-100 px-10 py-8 shadow-sm">
            <p class="text-sm font-semibold text-base-content/70">Donation received</p>
            <p class="mt-2 text-4xl font-semibold tracking-tight text-base-content">
              Rp {DonationPresenter.format_idr(@current.amount)}
            </p>
            <p class="mt-2 text-xl font-semibold text-base-content">{@current.donor_name}</p>
            <p
              :if={DonationPresenter.present_message?(@current.message)}
              class="mt-3 text-base text-base-content/70"
            >
              "{@current.message}"
            </p>
          </div>
        <% else %>
          <h1 class="text-base font-semibold text-base-content/60">Overlay</h1>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp start_next_alert(%{assigns: %{current: nil, queue: [next | rest]}} = socket) do
    Process.send_after(self(), {:dismiss_current, next.id}, 5_000)

    socket
    |> assign(:current, next)
    |> assign(:queue, rest)
  end

  defp start_next_alert(socket), do: socket
end
