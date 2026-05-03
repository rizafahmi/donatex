defmodule Donatex.Mayar.Webhook do
  @moduledoc false

  defmodule PaymentReceived do
    @moduledoc false

    @enforce_keys [:event, :mayar_transaction_id, :amount, :transaction_status]
    defstruct [:event, :mayar_transaction_id, :donor_name, :amount, :transaction_status]

    @type t :: %__MODULE__{
            event: String.t(),
            mayar_transaction_id: String.t(),
            donor_name: String.t() | nil,
            amount: pos_integer(),
            transaction_status: String.t()
          }
  end

  @type parse_error :: :invalid_payload | {:missing_field, atom()}
  @type parse_result :: {:ok, PaymentReceived.t()} | :ignore | {:error, parse_error()}

  @spec parse(map()) :: parse_result()
  def parse(%{"event" => event} = payload) when is_binary(event) do
    with :ok <- ensure_payment_received(event),
         {:ok, data} <- fetch_data(payload),
         {:ok, mayar_transaction_id} <-
           fetch_required_binary(
             data,
             ["transactionId", "id", "referenceId", "reference_id"],
             :mayar_transaction_id
           ),
         {:ok, amount} <- fetch_amount(data),
         {:ok, transaction_status} <-
           fetch_required_binary(
             data,
             ["transactionStatus", "status", "paymentStatus"],
             :transaction_status
           ) do
      {:ok,
       %PaymentReceived{
         event: event,
         mayar_transaction_id: mayar_transaction_id,
         donor_name: fetch_optional_binary(data, ["customerName"]),
         amount: amount,
         transaction_status: transaction_status
       }}
    else
      error -> error
    end
  end

  def parse(%{"event.received" => event} = payload) when is_binary(event) do
    parse(Map.put(payload, "event", event))
  end

  def parse(_payload), do: {:error, :invalid_payload}

  defp ensure_payment_received("payment.received"), do: :ok
  defp ensure_payment_received(_event), do: :ignore

  defp fetch_data(payload) do
    case Map.get(payload, "data") do
      %{} = data -> {:ok, data}
      nil -> {:error, {:missing_field, :data}}
      _other -> {:error, :invalid_payload}
    end
  end

  defp fetch_required_binary(data, keys, field) do
    case fetch_optional_binary(data, keys) do
      nil -> {:error, {:missing_field, field}}
      value -> {:ok, value}
    end
  end

  defp fetch_optional_binary(data, keys) do
    Enum.find_value(keys, &normalize_binary(Map.get(data, &1)))
  end

  defp fetch_amount(data) do
    case normalize_amount(Map.get(data, "amount")) do
      nil -> {:error, {:missing_field, :amount}}
      amount -> {:ok, amount}
    end
  end

  defp normalize_amount(value) when is_integer(value) and value > 0, do: value

  defp normalize_amount(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} when parsed > 0 -> parsed
      _error -> nil
    end
  end

  defp normalize_amount(_value), do: nil

  defp normalize_binary(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_binary(_value), do: nil
end
