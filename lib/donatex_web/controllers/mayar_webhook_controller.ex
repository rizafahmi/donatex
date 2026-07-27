defmodule DonatexWeb.MayarWebhookController do
  use DonatexWeb, :controller

  require Logger

  alias Donatex.Donations
  alias Donatex.Mayar.Client
  alias Donatex.Mayar.Webhook
  alias DonatexWeb.DonationPresenter

  def create(conn, params) do
    # Always log raw payload for debugging webhook issues
    Logger.info("Mayar webhook raw_payload=#{inspect(redacted_webhook_payload(params))}")
    _ = maybe_process_webhook(params)
    json(conn, %{ok: true})
  end

  defp redacted_webhook_payload(params) do
    # Redact sensitive fields while keeping structure for debugging
    params
    |> Map.update("data", %{}, fn data ->
      data
      |> Map.drop(["qrImageUrl", "qr_image_url", "url"])
      |> Map.update("amount", "[amount]", &to_string/1)
    end)
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
    payment_received
    |> find_donation_for_webhook()
    |> handle_donation_match(payment_received)
  end

  defp handle_donation_match({:exact, donation}, payment_received) do
    mark_donation_paid(donation, payment_received)
  end

  defp handle_donation_match(:ignored, _payment_received), do: :ok

  defp handle_donation_match({:ok, donation, _original_tx_id}, payment_received) do
    Logger.info(
      "Mayar webhook Mayar lookup match mayar_transaction_id=#{payment_received.mayar_transaction_id} donation_id=#{donation.id}"
    )

    update_transaction_id_and_mark_paid(donation, payment_received)
  end

  defp handle_donation_match({:fallback, donation, _new_transaction_id}, payment_received) do
    Logger.info(
      "Mayar webhook fallback atomic claim mayar_transaction_id=#{payment_received.mayar_transaction_id} donation_id=#{donation.id}"
    )

    # Atomic claim already set the tx_id and marked paid — just broadcast
    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "donations:paid",
      {:donation_paid, DonationPresenter.payload(donation)}
    )

    :ok
  end

  defp handle_donation_match(nil, payment_received) do
    Logger.error(
      "Mayar webhook orphan payment - no matching donation found mayar_transaction_id=#{payment_received.mayar_transaction_id} amount=#{payment_received.amount} donor_name=#{inspect(payment_received.donor_name)}"
    )

    :ok
  end

  defp update_transaction_id_and_mark_paid(donation, payment_received) do
    case Donations.update_mayar_transaction_id(donation, payment_received.mayar_transaction_id) do
      {:ok, updated_donation} ->
        mark_donation_paid(updated_donation, payment_received)

      {:error, reason} ->
        Logger.warning(
          "Mayar webhook failed to update transaction id mayar_transaction_id=#{payment_received.mayar_transaction_id} reason=#{inspect(reason)}"
        )

        :ok
    end
  end

  # Try exact match first, then try Mayar lookup, then fallback by amount
  defp find_donation_for_webhook(%Webhook.PaymentReceived{} = payment_received) do
    # Try exact transaction ID match first
    case Donations.get_donation_by_mayar_transaction_id(payment_received.mayar_transaction_id) do
      %{amount: amount} = donation when amount == payment_received.amount ->
        {:exact, donation}

      %{amount: expected_amount} ->
        # Transaction ID exists but amount doesn't match - log warning, don't treat as orphan
        Logger.warning(
          "Mayar webhook amount mismatch mayar_transaction_id=#{payment_received.mayar_transaction_id} expected_amount=#{expected_amount} payload_amount=#{payment_received.amount}"
        )

        :ignored

      nil ->
        find_donation_without_exact_match(payment_received)
    end
  end

  defp find_donation_without_exact_match(%Webhook.PaymentReceived{} = payment_received) do
    case lookup_original_transaction_id(payment_received.mayar_transaction_id) do
      {:ok, original_tx_id} when original_tx_id != payment_received.mayar_transaction_id ->
        Logger.info(
          "Mayar webhook looked up original transaction_id=#{original_tx_id} for confirmation_id=#{payment_received.mayar_transaction_id}"
        )

        find_donation_by_original_transaction_id(payment_received, original_tx_id)

      _ ->
        find_by_amount_fallback(payment_received)
    end
  end

  defp find_donation_by_original_transaction_id(
         %Webhook.PaymentReceived{} = payment_received,
         original_tx_id
       ) do
    case Donations.get_donation_by_mayar_transaction_id(original_tx_id) do
      %{amount: amount} = donation when amount == payment_received.amount ->
        {:ok, donation, original_tx_id}

      _ ->
        find_by_amount_fallback(payment_received)
    end
  end

  # Fallback: atomic claim by amount (fail-closed when ambiguous)
  defp find_by_amount_fallback(%Webhook.PaymentReceived{} = payment_received) do
    case Donations.claim_fallback_donation(
           payment_received.amount,
           payment_received.donor_name,
           payment_received.mayar_transaction_id
         ) do
      {:ok, donation, true} ->
        # Log warning if this was a risky match (amount-only, no donor_name)
        other_pending = Donations.count_pending_by_amount(payment_received.amount)

        if other_pending > 0 do
          Logger.warning(
            "Mayar webhook claim_fallback: atomically claimed donation_id=#{donation.id} at amount=#{payment_received.amount}, #{other_pending} other pending remain"
          )
        end

        {:fallback, donation, payment_received.mayar_transaction_id}

      {:error, :ambiguous} ->
        Logger.warning(
          "Mayar webhook ambiguous amount fallback rejected: amount=#{payment_received.amount} donor_name=#{inspect(payment_received.donor_name)}"
        )

        nil

      {:error, :not_found} ->
        nil
    end
  end

  # Look up transaction in Mayar API to find original QR transaction ID
  defp lookup_original_transaction_id(confirmation_tx_id) do
    case Client.lookup_transaction(confirmation_tx_id) do
      {:ok, %{"data" => data}} ->
        # Try to find original QR transaction ID from various possible field names
        original_tx_id =
          Enum.find_value(
            ["originalTransactionId", "qrTransactionId", "referenceId", "reference"],
            fn field ->
              data
              |> Map.get(field)
              |> non_empty_binary()
            end
          )

        {:ok, original_tx_id}

      _ ->
        {:error, :lookup_failed}
    end
  rescue
    _ -> {:error, :lookup_failed}
  end

  defp non_empty_binary(value) when is_binary(value) and byte_size(value) > 0, do: value
  defp non_empty_binary(_value), do: nil

  defp mark_donation_paid(donation, payment_received) do
    case Donations.mark_paid_with_change(donation) do
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

  defp paid_status?(status) when is_binary(status) do
    normalize_status(status) in ["paid", "success"]
  end

  defp normalize_status(status) when is_binary(status) do
    status
    |> String.trim()
    |> String.downcase()
  end

  defp format_parse_error({:missing_field, field}) when is_atom(field),
    do: "missing_field=#{field}"

  defp format_parse_error(other), do: inspect(other)
end
