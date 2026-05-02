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
         true <- webhook_paid?(params),
         %{amount: expected_amount} <-
           Donations.get_donation_by_mayar_transaction_id(mayar_transaction_id),
         true <- webhook_amount_match?(params, expected_amount),
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

  defp webhook_paid?(%{"data" => %{"transactionStatus" => status}}) when is_binary(status),
    do: String.downcase(String.trim(status)) == "paid"

  defp webhook_paid?(%{"data" => %{"status" => status}}) when is_binary(status),
    do: String.downcase(String.trim(status)) == "paid"

  defp webhook_paid?(_params), do: false

  defp webhook_amount_match?(%{"data" => %{"amount" => amount}}, expected_amount)
       when is_integer(amount) and is_integer(expected_amount),
       do: amount == expected_amount

  defp webhook_amount_match?(%{"data" => %{"amount" => amount}}, expected_amount)
       when is_binary(amount) and is_integer(expected_amount) do
    case Integer.parse(String.trim(amount)) do
      {parsed, ""} -> parsed == expected_amount
      _error -> false
    end
  end

  defp webhook_amount_match?(_params, _expected_amount), do: false
end
