defmodule DonatexWeb.MayarWebhookController do
  use DonatexWeb, :controller

  alias Donatex.Donations
  alias Donatex.Mayar.Webhook
  alias DonatexWeb.DonationPresenter

  def create(conn, params) do
    _ = maybe_process_webhook(params)
    json(conn, %{ok: true})
  end

  defp maybe_process_webhook(params) do
    with {:ok, %Webhook.PaymentReceived{mayar_transaction_id: mayar_transaction_id}} <-
           Webhook.parse(params),
         {:ok, donation, true} <-
           Donations.mark_paid_by_mayar_transaction_id_with_change(mayar_transaction_id) do
      Phoenix.PubSub.broadcast(
        Donatex.PubSub,
        "donations:paid",
        {:donation_paid, DonationPresenter.payload(donation)}
      )

      :ok
    else
      _ -> :ok
    end
  end
end
