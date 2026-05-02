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

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h1 class="text-2xl font-semibold text-base-content">Admin</h1>

      <div class="mt-8 space-y-4">
        <div class="grid gap-3 text-sm font-semibold text-base-content/70 sm:grid-cols-6">
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
            class="grid items-center gap-3 rounded-2xl border border-base-300/70 bg-base-100 px-4 py-3 text-sm text-base-content sm:grid-cols-6"
          >
            <div class="sm:col-span-2">
              <div id={"donation-#{donation.id}"} class="font-semibold">{donation.donor_name}</div>
              <div class="mt-1 text-xs text-base-content/60">{donation.mayar_transaction_id}</div>
            </div>
            <div>Rp {DonationPresenter.format_idr(donation.amount)}</div>
            <div class="uppercase tracking-wide text-xs">{donation.status}</div>
            <div class="text-xs">{to_string(donation.alerted)}</div>
            <div class="sm:text-right">
              <button
                type="button"
                phx-click="replay"
                phx-value-id={donation.id}
                class="rounded-xl bg-base-200 px-4 py-2 text-xs font-semibold text-base-content hover:bg-base-300"
              >
                Replay
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
