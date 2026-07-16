defmodule DonatexWeb.AdminLive do
  use DonatexWeb, :live_view

  require Logger

  alias Donatex.Donations
  alias DonatexWeb.DonationPresenter

  @default_filter "all"
  @filters ~w(all tips feedback)

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:created")
      Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")
      Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:alerted")
    end

    {:ok,
     socket
     |> assign(:stats, Donations.get_donation_stats())
     |> assign(:filters, @filters)
     |> assign_filtered_donations(@default_filter)}
  end

  @impl Phoenix.LiveView
  def handle_event("set_filter", %{"filter" => filter}, socket)
      when filter in @filters do
    {:noreply, assign_filtered_donations(socket, filter, reset: true)}
  end

  def handle_event("replay", %{"id" => id}, socket) do
    case Donations.get_donation_by_id(id) do
      nil ->
        Logger.warning("Admin replay failed donation_id=#{id} reason=not_found")
        {:noreply, put_flash(socket, :error, "Donation not found")}

      donation ->
        if replayable?(donation) do
          Logger.info(
            "Admin replay sent donation_id=#{donation.id} mayar_transaction_id=#{donation.mayar_transaction_id}"
          )

          Phoenix.PubSub.broadcast(
            Donatex.PubSub,
            "donations:paid",
            {:donation_paid, DonationPresenter.payload(donation)}
          )

          {:noreply, put_flash(socket, :info, "Replayed")}
        else
          Logger.warning(
            "Admin replay rejected donation_id=#{id} status=#{donation.status} amount=#{inspect(donation.amount)}"
          )

          {:noreply, put_flash(socket, :error, "Only paid tips can be replayed")}
        end
    end
  end

  def handle_event("mark_paid", %{"id" => id}, socket) do
    case Donations.mark_paid_by_id(id) do
      {:ok, donation, true} ->
        Logger.info("Admin marked paid donation_id=#{id}")

        Phoenix.PubSub.broadcast(
          Donatex.PubSub,
          "donations:paid",
          {:donation_paid, DonationPresenter.payload(donation)}
        )

        {:noreply, put_flash(socket, :info, "Marked as paid")}

      {:ok, _donation, false} ->
        {:noreply, put_flash(socket, :info, "Already paid")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Donation not found")}

      {:error, reason} ->
        Logger.warning("Admin mark paid failed donation_id=#{id} reason=#{inspect(reason)}")
        {:noreply, put_flash(socket, :error, "Failed to mark as paid")}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:donation_created, donation}, socket) do
    filter = socket.assigns.filter

    socket =
      if matches_created_filter?(filter, donation.status) do
        socket
        |> assign(:has_donations?, true)
        |> stream_insert(:donations, donation, at: 0)
      else
        socket
      end

    {:noreply,
     socket
     |> assign(:stats, Donations.get_donation_stats())}
  end

  def handle_info({:donation_paid, %{id: id}}, socket) do
    case Donations.get_donation_by_id(id) do
      nil ->
        {:noreply, socket}

      donation ->
        filter = socket.assigns.filter

        socket =
          cond do
            filter in ["tips", "all"] ->
              socket
              |> assign(:has_donations?, true)
              |> stream_insert(:donations, donation)

            true ->
              socket
          end

        {:noreply,
         socket
         |> assign(:stats, Donations.get_donation_stats())}
    end
  end

  def handle_info({:donation_alerted, donation}, socket) do
    socket =
      if socket.assigns.filter in ["tips", "all"] do
        stream_insert(socket, :donations, donation)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Admin Panel
        <:subtitle>Manage livestream donations, mark manual payments, and replay alerts.</:subtitle>
      </.header>
      
    <!-- Status telemetry bar -->
      <div class="border border-stroke/50 bg-surface/30 rounded-2xl p-4 mb-6">
        <div class="flex flex-wrap items-center justify-between gap-4 text-xs font-semibold uppercase tracking-[0.18em] text-text-muted">
          <div class="flex items-center gap-6">
            <span class="flex items-center gap-2">
              <span class="h-1.5 w-1.5 rounded-full bg-accent"></span>
              Paid:
              <strong class="text-text">Rp {DonationPresenter.format_idr(@stats.paid_sum)}</strong>
              ({@stats.paid_count})
            </span>
            <span class="flex items-center gap-2">
              <span class="h-1.5 w-1.5 rounded-full bg-accent-2"></span>
              Pending: <strong class="text-text">{@stats.pending_count}</strong>
            </span>
          </div>
          <div class="flex items-center gap-2">
            <span class="h-1.5 w-1.5 rounded-full bg-accent animate-pulse"></span>
            OBS URL:
            <a
              href={~p"/overlay"}
              target="_blank"
              class="text-text underline lowercase tracking-normal hover:text-accent transition"
            >
              /overlay
            </a>
          </div>
        </div>
      </div>
      
    <!-- Filters -->
      <div class="flex flex-wrap items-center justify-between gap-4 mb-8">
        <div class="flex items-center gap-1.5 bg-surface-2/40 border border-stroke/40 rounded-full p-1">
          <button
            :for={f <- @filters}
            type="button"
            phx-click="set_filter"
            phx-value-filter={f}
            class={[
              "px-5 py-1.5 text-[10px] font-semibold uppercase tracking-[0.24em] rounded-full transition-all duration-200 focus:outline-hidden cursor-pointer",
              @filter == f && "bg-accent text-background shadow-md shadow-accent/20",
              @filter != f && "text-text-muted hover:text-text hover:bg-surface-3/30"
            ]}
          >
            {f}
          </button>
        </div>
      </div>
      
    <!-- Empty State -->
      <div
        id="donations-empty"
        class={[
          if(@has_donations?, do: "hidden"),
          "flex flex-col items-center justify-center rounded-[2rem] border border-dashed border-stroke/50 bg-surface/25 px-6 py-16 text-center"
        ]}
      >
        <div class="inline-flex h-12 w-12 items-center justify-center rounded-full bg-surface-2/60 text-text-muted">
          <.icon name="hero-chat-bubble-left-right" class="h-6 w-6" />
        </div>
        <h3 class="mt-4 text-sm font-semibold text-text">No notes yet</h3>
        <p class="mt-1 text-xs text-text-muted/80 max-w-sm">
          Free feedback and appreciation tips will show up here in real time.
        </p>
        <div class="mt-6">
          <.button navigate={~p"/"} variant="ghost" class="text-xs">
            Go to Feedback Page
          </.button>
        </div>
      </div>
      
    <!-- Donations Stream -->
      <div
        id="donations"
        phx-update="stream"
        class={[if(not @has_donations?, do: "hidden"), "grid gap-4 sm:gap-5"]}
      >
        <article
          :for={{dom_id, donation} <- @streams.donations}
          id={dom_id}
          class="relative isolate overflow-hidden rounded-[2.5rem] border border-stroke/60 bg-surface/45 px-6 py-6 text-text shadow-xl shadow-black/30 sm:px-8 sm:py-7 transition-all duration-300 hover:border-stroke hover:bg-surface/60"
        >
          <div class="relative flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
            <div class="min-w-0 flex-1">
              <div id={"donation-#{donation.id}"} class="text-base font-semibold leading-6">
                {donation.donor_name}
              </div>
              <div class="mt-2 flex flex-wrap items-center gap-2 text-[10px] font-semibold uppercase tracking-[0.24em] text-text-muted">
                <span id={"donation-#{donation.id}-reaction"} class="text-text">
                  {DonationPresenter.reaction_label(donation.reaction)}
                </span>
                <span id={"donation-#{donation.id}-type"}>
                  {DonationPresenter.note_type(donation)}
                </span>
                <time
                  id={"donation-#{donation.id}-time"}
                  datetime={donation.inserted_at}
                  class="normal-case tracking-normal text-text-muted/80"
                >
                  {DonationPresenter.format_timestamp(donation.inserted_at)}
                </time>
              </div>
              <div
                :if={donation.mayar_transaction_id}
                class="mt-1 break-all text-[10px] font-semibold tracking-[0.22em] text-text-muted/80"
              >
                {donation.mayar_transaction_id}
              </div>
              <p
                :if={DonationPresenter.present_message?(donation.message)}
                class="mt-4 text-sm italic text-text-muted font-medium bg-background/25 border border-stroke/20 rounded-xl px-4 py-3 max-w-[65ch]"
              >
                "{donation.message}"
              </p>
            </div>

            <div class="sm:text-right shrink-0">
              <div
                :if={donation.amount}
                id={"donation-#{donation.id}-amount"}
                class="text-xl font-bold tracking-tight text-text"
              >
                Rp {DonationPresenter.format_idr(donation.amount)}
              </div>

              <div class="mt-3 flex flex-wrap items-center gap-2 sm:justify-end">
                <div class={[
                  "inline-flex items-center rounded-full border px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.24em]",
                  donation.status == "paid" && "border-accent/30 bg-accent/10 text-accent",
                  donation.status == "pending" && "border-accent-2/30 bg-accent-2/10 text-accent-2"
                ]}>
                  {donation.status}
                </div>

                <div class="inline-flex items-center gap-2 rounded-full border border-stroke/60 bg-background/20 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.24em] text-text-muted">
                  <span class="relative flex size-2 items-center justify-center">
                    <span
                      :if={donation.alerted}
                      class="relative inline-flex size-1.5 rounded-full bg-accent"
                    >
                    </span>
                    <span
                      :if={!donation.alerted}
                      class="relative inline-flex size-1.5 rounded-full bg-accent-2 animate-pulse"
                    >
                    </span>
                  </span>
                  <span>Alerted</span>
                  <span class="text-text">{if donation.alerted, do: "Yes", else: "No"}</span>
                </div>
              </div>
            </div>
          </div>

          <div
            :if={replayable?(donation) or donation.status == "pending"}
            class="relative mt-6 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-end"
          >
            <.button
              :if={replayable?(donation)}
              type="button"
              variant="primary"
              phx-click="replay"
              phx-value-id={donation.id}
              class="w-full px-5 py-2.5 text-xs sm:w-auto phx-click-loading:opacity-60 phx-click-loading:pointer-events-none"
            >
              Replay Alert
            </.button>

            <.button
              :if={donation.status == "pending"}
              type="button"
              variant="ghost"
              phx-click="mark_paid"
              phx-value-id={donation.id}
              class="w-full px-5 py-2.5 text-xs sm:w-auto phx-click-loading:opacity-60 phx-click-loading:pointer-events-none"
            >
              Mark Paid
            </.button>
          </div>
        </article>
      </div>
    </Layouts.app>
    """
  end

  defp assign_filtered_donations(socket, filter, opts \\ []) do
    donations = Donations.list_donations(filter)
    reset = Keyword.get(opts, :reset, false)

    socket
    |> assign(:filter, filter)
    |> assign(:has_donations?, donations != [])
    |> stream(:donations, donations, reset: reset)
  end

  defp matches_created_filter?("all", _status), do: true
  defp matches_created_filter?("tips", "pending"), do: true
  defp matches_created_filter?("feedback", "sent"), do: true
  defp matches_created_filter?(_filter, _status), do: false

  defp replayable?(%{status: "paid", amount: amount}) when not is_nil(amount), do: true
  defp replayable?(_donation), do: false
end
