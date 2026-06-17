defmodule DonatexWeb.AdminLive do
  use DonatexWeb, :live_view

  require Logger

  alias Donatex.Donations
  alias DonatexWeb.DonationPresenter

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :donations, Donations.list_donations())}
  end

  @impl Phoenix.LiveView
  def handle_event("replay", %{"id" => id}, socket) do
    case Donations.get_donation_by_id(id) do
      nil ->
        Logger.warning("Admin replay failed donation_id=#{id} reason=not_found")
        {:noreply, put_flash(socket, :error, "Donation not found")}

      donation ->
        Logger.info(
          "Admin replay sent donation_id=#{donation.id} mayar_transaction_id=#{donation.mayar_transaction_id}"
        )

        Phoenix.PubSub.broadcast(
          Donatex.PubSub,
          "donations:paid",
          {:donation_paid, DonationPresenter.payload(donation)}
        )

        {:noreply, put_flash(socket, :info, "Replayed")}
    end
  end

  def handle_event("mark_paid", %{"id" => id}, socket) do
    case Donations.mark_paid_by_id(id) do
      {:ok, donation, true} ->
        Logger.info("Admin marked paid donation_id=#{id}")

        {:noreply,
         socket
         |> put_flash(:info, "Marked as paid")
         |> stream_insert(:donations, donation)}

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
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h1 class="font-display text-2xl font-semibold text-text">Admin</h1>

      <div class="mt-8">
        <div id="donations" phx-update="stream" class="grid gap-4 sm:gap-5">
          <article
            :for={{dom_id, donation} <- @streams.donations}
            id={dom_id}
            class="relative isolate overflow-hidden rounded-[2.25rem] border border-stroke/60 bg-surface/45 px-5 py-5 text-text shadow-xl shadow-black/30 sm:px-6"
          >
            <div class="absolute inset-0 bg-linear-to-br from-accent/10 via-transparent to-accent-2/10" />
            <div class="absolute -left-24 top-10 h-56 w-56 rounded-full bg-accent/10 blur-3xl" />
            <div class="absolute -right-24 -bottom-12 h-64 w-64 rounded-full bg-accent-2/10 blur-3xl" />

            <div class="relative flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
              <div class="min-w-0">
                <div id={"donation-#{donation.id}"} class="text-base font-semibold leading-6">
                  {donation.donor_name}
                </div>
                <div class="mt-1 break-all text-[11px] font-semibold tracking-[0.22em] text-text-muted/90">
                  {donation.mayar_transaction_id}
                </div>
              </div>

              <div class="sm:text-right">
                <div class="text-xl font-semibold tracking-tight">
                  Rp {DonationPresenter.format_idr(donation.amount)}
                </div>

                <div class="mt-2 flex flex-wrap items-center gap-2 sm:justify-end">
                  <div class={[
                    "inline-flex items-center rounded-full border px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.24em]",
                    donation.status == "paid" && "border-accent/30 bg-accent/10 text-text",
                    donation.status == "pending" &&
                      "border-stroke/60 bg-background/20 text-text-muted"
                  ]}>
                    {donation.status}
                  </div>

                  <div class="inline-flex items-center gap-2 rounded-full border border-stroke/60 bg-background/20 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.24em] text-text-muted">
                    <span class="relative flex size-2 items-center justify-center">
                      <span
                        :if={donation.alerted}
                        class="relative inline-flex size-1.5 rounded-full bg-accent-2"
                      >
                      </span>
                      <span
                        :if={!donation.alerted}
                        class="relative inline-flex size-1.5 rounded-full bg-text-muted/40"
                      >
                      </span>
                    </span>
                    <span>Alerted</span>
                    <span class="text-text">{if donation.alerted, do: "Yes", else: "No"}</span>
                  </div>
                </div>
              </div>
            </div>

            <div class="relative mt-5 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-end">
              <.button
                type="button"
                variant="primary"
                phx-click="replay"
                phx-value-id={donation.id}
                class="w-full px-5 py-2.5 text-xs sm:w-auto"
              >
                Replay Alert
              </.button>

              <.button
                :if={donation.status == "pending"}
                type="button"
                variant="ghost"
                phx-click="mark_paid"
                phx-value-id={donation.id}
                class="w-full px-5 py-2.5 text-xs sm:w-auto"
              >
                Mark Paid
              </.button>
            </div>
          </article>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
