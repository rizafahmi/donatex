defmodule Donatex.Mayar.Client do
  @moduledoc false

  defmodule DynamicQr do
    @moduledoc false

    @enforce_keys [:mayar_transaction_id, :amount, :qr_image_url]
    defstruct [:mayar_transaction_id, :amount, :qr_image_url, :expires_at]

    @type t :: %__MODULE__{
            mayar_transaction_id: String.t(),
            amount: pos_integer(),
            qr_image_url: String.t(),
            expires_at: DateTime.t() | nil
          }
  end

  @type error_reason ::
          :invalid_amount
          | :not_implemented
          | :unauthorized
          | :rate_limited
          | :bad_request
          | :upstream_error
          | :network_error
          | {:unexpected_response, term()}

  @type create_qr_result :: {:ok, DynamicQr.t()} | {:error, error_reason()}

  defmodule Impl do
    @moduledoc false

    @callback create_qr(amount_idr :: pos_integer()) :: Donatex.Mayar.Client.create_qr_result()
  end

  defmodule Stub do
    @moduledoc false

    @behaviour Impl

    @impl true
    def create_qr(_amount_idr), do: {:error, :not_implemented}
  end

  @spec create_qr(amount_idr :: pos_integer()) :: create_qr_result()
  def create_qr(amount_idr) when is_integer(amount_idr) and amount_idr > 0 do
    impl().create_qr(amount_idr)
  end

  def create_qr(_amount_idr), do: {:error, :invalid_amount}

  defp impl do
    Application.get_env(:donatex, :mayar_client_impl, Stub)
  end
end
