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
          <audio
            phx-hook="PlaySound"
            id={"audio-#{@current.id}"}
            src="/smb_stage_clear.wav"
            preload="auto"
            class="hidden"
          >
          </audio>
          <div class="relative w-full max-w-xl animate-overlay-show">
            <!-- Decorative background glow -->
            <div class="absolute -inset-1 rounded-[2.5rem] bg-gradient-to-r from-accent/50 to-accent-2/50 opacity-40 blur-xl">
            </div>

            <div class="relative flex flex-col items-center justify-center rounded-[2.25rem] border border-stroke/50 bg-surface/85 px-10 py-12 text-center shadow-2xl shadow-black/60 backdrop-blur-md">
              <div class="animate-text-reveal flex items-center gap-2">
                <.icon name="hero-sparkles-solid" class="h-5 w-5 text-accent" />
                <p class="text-sm font-bold uppercase tracking-[0.25em] text-accent">
                  New Donation!
                </p>
                <.icon name="hero-sparkles-solid" class="h-5 w-5 text-accent" />
              </div>

              <p class="animate-amount-pop mt-4 bg-gradient-to-br from-white to-white/60 bg-clip-text font-display text-7xl font-bold tracking-tight text-transparent drop-shadow-sm">
                Rp {DonationPresenter.format_idr(@current.amount)}
              </p>

              <div class="animate-message-reveal mt-6 flex flex-col items-center gap-4">
                <div class="inline-flex items-center gap-2 rounded-full border border-stroke/40 bg-surface-2/60 px-5 py-2 shadow-inner">
                  <.icon name="hero-user-solid" class="h-4 w-4 text-text-muted" />
                  <span class="text-lg font-semibold text-text">{@current.donor_name}</span>
                </div>

                <p
                  :if={DonationPresenter.present_message?(@current.message)}
                  class="mt-2 max-w-md text-xl italic leading-relaxed text-text-muted"
                >
                  "{@current.message}"
                </p>
              </div>
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
        Process.send_after(self(), {:dismiss_current, next.id}, 7_000)

        socket
        |> assign(:current, next)
        |> assign(:queue, rest)

      {:empty, _queue} ->
        socket
    end
  end

  defp start_next_alert(socket), do: socket
end
