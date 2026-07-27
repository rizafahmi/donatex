defmodule DonatexWeb.OverlayLive do
  use DonatexWeb, :live_view

  alias Donatex.Donations
  alias Donatex.Reactions
  alias DonatexWeb.DonationPresenter

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")
      Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:created")
    end

    queue =
      Donations.list_paid_unalerted_donations()
      |> Enum.map(&DonationPresenter.payload/1)
      |> :queue.from_list()

    {:ok,
     socket
     |> assign(:queue, queue)
     |> assign(:current, nil)
     |> assign(:floats, %{})
     |> assign(:page_title, "OBS Overlay")
     |> assign(
       :meta_description,
       "OBS overlay page for displaying live alerts and emoji reactions."
     )
     |> assign(:meta_robots, "noindex, nofollow")
     |> assign(
       :canonical_url,
       (Application.get_env(:donatex, :app)[:base_url] |> String.trim_trailing("/")) <> "/overlay"
     )
     |> start_next_alert()}
  end

  @impl Phoenix.LiveView
  def handle_info({:donation_paid, donation_payload}, socket) do
    {:noreply,
     socket
     |> update(:queue, &:queue.in(donation_payload, &1))
     |> start_next_alert()}
  end

  def handle_info({:donation_created, %{status: "sent"} = donation}, socket) do
    case build_float(donation) do
      nil ->
        {:noreply, socket}

      float ->
        Process.send_after(self(), {:dismiss_float, float.id}, float.duration_ms)

        {:noreply, update(socket, :floats, &Map.put(&1, float.id, float))}
    end
  end

  def handle_info({:donation_created, _donation}, socket), do: {:noreply, socket}

  def handle_info({:dismiss_float, id}, socket) do
    {:noreply, update(socket, :floats, &Map.delete(&1, id))}
  end

  def handle_info({:dismiss_current, id}, socket) do
    socket =
      case socket.assigns.current do
        %{id: ^id} ->
          case Donations.mark_donation_alerted_by_id(id) do
            {:ok, donation} ->
              Phoenix.PubSub.broadcast(
                Donatex.PubSub,
                "donations:alerted",
                {:donation_alerted, donation}
              )

              socket

            _ ->
              socket
          end
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
    <Layouts.app flash={@flash} flash_generations={@flash_generations} variant="overlay">
      <div class="obs-overlay-container">
        <div
          :for={{id, float} <- @floats}
          id={"obs-float-#{id}"}
          class="obs-float-emoji"
          style={float_style(float)}
          aria-hidden="true"
        >
          {float.emoji}
        </div>
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
            
    <!-- Terminal Header Title Bar -->
            <div class="absolute top-0 left-0 right-0 z-20 flex items-center justify-between border-b border-stroke/40 bg-surface-2/65 px-6 py-2.5 rounded-t-2xl font-mono text-[11px] font-semibold tracking-wider text-text-muted/70 uppercase">
              <div class="flex items-center gap-1.5 select-none">
                <span class="h-3 w-3 rounded-full bg-[#ff5f56]"></span>
                <span class="h-3 w-3 rounded-full bg-[#ffbd2e]"></span>
                <span class="h-3 w-3 rounded-full bg-[#27c93f]"></span>
              </div>
              <div class="select-none">notable-terminal | alert</div>
              <div class="w-12"></div>
            </div>
            <!-- Terminal Console Content -->
            <div class="relative z-10 flex h-full flex-col justify-center items-center gap-3 pt-14 pb-5 px-8">
              <div class="obs-overlay-main-text font-mono tracking-tight text-2xl font-bold">
                <span class="text-accent select-none font-bold">~ $</span>
                <span class="text-text font-semibold ml-1">tip-alert</span>
                <span class="text-text-muted/70 font-medium font-sans">--from=</span>
                <span class="text-accent drop-shadow-[0_2px_10px_rgba(56,189,248,0.45)] font-bold">
                  {@current.donor_name}
                </span>
                <span class="text-text-muted/70 font-medium font-sans">--amount=</span>
                <span class="text-accent-2 drop-shadow-[0_2px_10px_rgba(192,132,252,0.45)] font-extrabold">
                  Rp {DonationPresenter.format_idr(@current.amount)}
                </span>
                <span class="text-accent animate-pulse font-bold select-none ml-1">_</span>
              </div>
              <div
                :if={DonationPresenter.present_message?(@current.message)}
                class="obs-overlay-sub-text font-mono text-base text-text-muted/95 italic bg-background/55 border border-stroke/45 px-5 py-1.5 rounded-xl flex items-center gap-3 max-w-[85ch] shadow-inner"
              >
                <span class="text-accent font-bold select-none">&gt;</span>
                <span>"{@current.message}"</span>
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

  defp build_float(%{id: id, reaction: reaction}) do
    case Reactions.pick_emoji(reaction) do
      nil ->
        nil

      emoji ->
        %{
          id: id,
          emoji: emoji,
          start_x: Enum.random(8..85),
          drift_x: Enum.random(-18..18),
          duration_ms: Enum.random(3_000..4_000)
        }
    end
  end

  defp float_style(float) do
    [
      "--float-start-x: #{float.start_x}%;",
      "--float-drift-x: #{float.drift_x}vw;",
      "--float-duration: #{float.duration_ms}ms;"
    ]
  end

  defp start_next_alert(%{assigns: %{current: nil, queue: queue}} = socket) do
    case :queue.out(queue) do
      {{:value, next}, rest} ->
        Process.send_after(self(), {:dismiss_current, next.id}, 8_500)

        socket
        |> assign(:current, next)
        |> assign(:queue, rest)

      {:empty, _queue} ->
        socket
    end
  end

  defp start_next_alert(socket), do: socket
end
