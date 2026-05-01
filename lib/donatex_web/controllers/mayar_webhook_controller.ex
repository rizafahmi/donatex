defmodule DonatexWeb.MayarWebhookController do
  use DonatexWeb, :controller

  alias Donatex.Donations

  def create(conn, params) do
    _ = maybe_process_webhook(params)
    json(conn, %{ok: true})
  end

  defp maybe_process_webhook(params) do
    with "payment.received" <- fetch_event(params),
         %{} = data <- Map.get(params, "data"),
         {:ok, mayar_transaction_id} <- fetch_transaction_id(data),
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

  defp fetch_event(%{"event" => event}) when is_binary(event), do: event
  defp fetch_event(%{"event.received" => event}) when is_binary(event), do: event
  defp fetch_event(_params), do: nil

  defp fetch_transaction_id(%{"transactionId" => id}) when is_binary(id) and byte_size(id) > 0,
    do: {:ok, id}

  defp fetch_transaction_id(%{"id" => id}) when is_binary(id) and byte_size(id) > 0, do: {:ok, id}
  defp fetch_transaction_id(_data), do: :error

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
