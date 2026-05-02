defmodule DonatexWeb.MayarWebhookController do
  use DonatexWeb, :controller

  alias Donatex.Donations
  alias Donatex.Mayar.Webhook

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
        {:donation_paid, donation_payload(donation)}
      )

      :ok
    else
      _ -> :ok
    end
  end

  defp donation_payload(donation) do
    %{
      id: donation.id,
      mayar_transaction_id: donation.mayar_transaction_id,
      donor_name: donation.donor_name,
      amount: donation.amount,
      message: donation.message,
      inserted_at: donation.inserted_at
    }
  end
end
