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
         |> stream(:donations, [donation], at: -1)}

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

      <div class="mt-8 space-y-4">
        <div class="grid gap-3 text-sm font-semibold text-text-muted sm:grid-cols-6">
          <div class="sm:col-span-2">Donor</div>
          <div>Amount</div>
          <div>Status</div>
          <div>Alerted</div>
          <div></div>
        </div>

        <div id="donations" phx-update="stream" class="space-y-3">
          <div
            :for={{dom_id, donation} <- @streams.donations}
            id={dom_id}
            class="grid items-center gap-3 rounded-2xl border border-stroke/60 bg-surface/55 px-4 py-3 text-sm text-text shadow-sm shadow-black/25 sm:grid-cols-6"
          >
            <div class="sm:col-span-2">
              <div id={"donation-#{donation.id}"} class="font-semibold">{donation.donor_name}</div>
              <div class="mt-1 text-xs text-text-muted">{donation.mayar_transaction_id}</div>
            </div>
            <div>Rp {DonationPresenter.format_idr(donation.amount)}</div>
            <div class="text-xs font-semibold uppercase tracking-[0.18em] text-text-muted">
              {donation.status}
            </div>
            <div class="text-xs text-text-muted">{to_string(donation.alerted)}</div>
            <div class="flex items-center gap-2 sm:text-right">
              <.button
                :if={donation.status == "pending"}
                type="button"
                variant="ghost"
                phx-click="mark_paid"
                phx-value-id={donation.id}
                class="px-3 py-1.5 text-xs"
              >
                Mark Paid
              </.button>
              <.button
                type="button"
                variant="ghost"
                phx-click="replay"
                phx-value-id={donation.id}
                class="px-3 py-1.5 text-xs"
              >
                Replay
              </.button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
