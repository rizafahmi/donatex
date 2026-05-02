defmodule DonatexWeb.MayarWebhookController do
  use DonatexWeb, :controller

  require Logger

  alias Donatex.Donations
  alias Donatex.Mayar.Webhook
  alias DonatexWeb.DonationPresenter

  def create(conn, params) do
    _ = maybe_process_webhook(params)
    json(conn, %{ok: true})
  end

  defp maybe_process_webhook(params) do
    case Webhook.parse(params) do
      :ignore ->
        :ok

      {:error, reason} ->
        Logger.warning("Mayar webhook rejected parse_error=#{format_parse_error(reason)}")
        :ok

      {:ok, %Webhook.PaymentReceived{} = payment_received} ->
        process_payment_received(payment_received)
    end
  end

  defp process_payment_received(%Webhook.PaymentReceived{} = payment_received) do
    if paid_status?(payment_received.transaction_status) do
      handle_paid_webhook(payment_received)
    else
      Logger.info(
        "Mayar webhook ignored non-paid transaction mayar_transaction_id=#{payment_received.mayar_transaction_id} status=#{normalize_status(payment_received.transaction_status)}"
      )

      :ok
    end
  end

  defp handle_paid_webhook(%Webhook.PaymentReceived{} = payment_received) do
    case Donations.get_donation_by_mayar_transaction_id(payment_received.mayar_transaction_id) do
      nil ->
        Logger.warning(
          "Mayar webhook donation not found mayar_transaction_id=#{payment_received.mayar_transaction_id} amount=#{payment_received.amount}"
        )

        :ok

      %{amount: expected_amount} when expected_amount != payment_received.amount ->
        Logger.warning(
          "Mayar webhook amount mismatch mayar_transaction_id=#{payment_received.mayar_transaction_id} expected_amount=#{expected_amount} payload_amount=#{payment_received.amount}"
        )

        :ok

      _donation ->
        case Donations.mark_paid_by_mayar_transaction_id_with_change(
               payment_received.mayar_transaction_id
             ) do
          {:ok, donation, true} ->
            Logger.info(
              "Mayar webhook accepted mayar_transaction_id=#{payment_received.mayar_transaction_id} donation_id=#{donation.id} amount=#{donation.amount}"
            )

            Phoenix.PubSub.broadcast(
              Donatex.PubSub,
              "donations:paid",
              {:donation_paid, DonationPresenter.payload(donation)}
            )

            :ok

          {:ok, donation, false} ->
            Logger.info(
              "Mayar webhook duplicate delivery mayar_transaction_id=#{payment_received.mayar_transaction_id} donation_id=#{donation.id}"
            )

            :ok

          {:error, reason} ->
            Logger.warning(
              "Mayar webhook failed to mark paid mayar_transaction_id=#{payment_received.mayar_transaction_id} reason=#{inspect(reason)}"
            )

            :ok
        end
    end
  end

  defp paid_status?(status) when is_binary(status), do: normalize_status(status) == "paid"

  defp normalize_status(status) when is_binary(status) do
    status
    |> String.trim()
    |> String.downcase()
  end

  defp format_parse_error({:missing_field, field}) when is_atom(field),
    do: "missing_field=#{field}"

  defp format_parse_error(other), do: inspect(other)
end
