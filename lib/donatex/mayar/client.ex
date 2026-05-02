defmodule Donatex.Mayar.Client do
  @moduledoc false

  alias Donatex.Config

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

  defmodule HTTP do
    @moduledoc false

    @behaviour Impl

    @impl true
    def create_qr(amount_idr) do
      case Req.post(request(), url: "/qrcode/create", json: %{amount: amount_idr}) do
        {:ok, %Req.Response{status: status, body: body}} -> normalize_response(status, body)
        {:error, %Req.TransportError{}} -> {:error, :network_error}
        {:error, _exception} -> {:error, :upstream_error}
      end
    end

    defp request do
      [
        base_url: Config.mayar_base_url(),
        auth: {:bearer, Config.mayar_api_key()},
        retry: false
      ]
      |> Keyword.merge(Application.get_env(:donatex, :mayar_req_options, []))
      |> Req.new()
    end

    defp normalize_response(status, body) when status in 200..299 do
      case build_dynamic_qr(body) do
        {:ok, dynamic_qr} -> {:ok, dynamic_qr}
        :error -> {:error, {:unexpected_response, body}}
      end
    end

    defp normalize_response(400, _body), do: {:error, :bad_request}
    defp normalize_response(401, _body), do: {:error, :unauthorized}
    defp normalize_response(429, _body), do: {:error, :rate_limited}
    defp normalize_response(status, _body) when status in 400..499, do: {:error, :bad_request}
    defp normalize_response(status, _body) when status in 500..599, do: {:error, :upstream_error}
    defp normalize_response(_status, body), do: {:error, {:unexpected_response, body}}

    defp build_dynamic_qr(%{"data" => data}) when is_map(data) do
      with {:ok, mayar_transaction_id} <- fetch_binary(data, ["transactionId", "id"]),
           {:ok, amount} <- fetch_positive_integer(data, ["amount"]),
           {:ok, qr_image_url} <- fetch_binary(data, ["url", "qrImageUrl", "qr_image_url"]),
           :ok <- validate_qr_image_url(qr_image_url),
           {:ok, expires_at} <-
             parse_expires_at(Map.get(data, "expiresAt") || Map.get(data, "expires_at")) do
        {:ok,
         %DynamicQr{
           mayar_transaction_id: mayar_transaction_id,
           amount: amount,
           qr_image_url: qr_image_url,
           expires_at: expires_at
         }}
      end
    end

    defp build_dynamic_qr(_body), do: :error

    defp fetch(data, keys, normalizer) do
      case Enum.find_value(keys, &normalizer.(Map.get(data, &1))) do
        nil -> :error
        value -> {:ok, value}
      end
    end

    defp fetch_binary(data, keys) do
      fetch(data, keys, &present_binary/1)
    end

    defp fetch_positive_integer(data, keys) do
      fetch(data, keys, &positive_integer/1)
    end

    defp parse_expires_at(nil), do: {:ok, nil}
    defp parse_expires_at(""), do: {:ok, nil}

    defp parse_expires_at(expires_at) when is_binary(expires_at) do
      case DateTime.from_iso8601(expires_at) do
        {:ok, parsed, _offset} -> {:ok, parsed}
        _error -> :error
      end
    end

    defp parse_expires_at(_expires_at), do: :error

    defp present_binary(value) when is_binary(value) do
      case String.trim(value) do
        "" -> nil
        trimmed -> trimmed
      end
    end

    defp present_binary(_value), do: nil

    defp positive_integer(value) when is_integer(value) and value > 0, do: value
    defp positive_integer(_value), do: nil

    defp validate_qr_image_url(url) when is_binary(url) do
      case String.trim(url) do
        <<"https://", _rest::binary>> ->
          :ok

        <<"http://", _rest::binary>> = http_url ->
          case URI.parse(http_url) do
            %URI{host: host} when host in ["localhost", "127.0.0.1", "0.0.0.0"] -> :ok
            _ -> :error
          end

        <<"data:image/", _rest::binary>> = data_url ->
          if String.contains?(data_url, ";base64,") do
            :ok
          else
            :error
          end

        _ ->
          :error
      end
    end

    defp validate_qr_image_url(_url), do: :error
  end

  @spec create_qr(amount_idr :: pos_integer()) :: create_qr_result()
  def create_qr(amount_idr) when is_integer(amount_idr) and amount_idr > 0 do
    impl().create_qr(amount_idr)
  end

  def create_qr(_amount_idr), do: {:error, :invalid_amount}

  defp impl do
    Application.get_env(:donatex, :mayar_client_impl, HTTP)
  end
end
