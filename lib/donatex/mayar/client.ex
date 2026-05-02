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

    require Logger

    @uuid_regex ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

    @impl true
    def create_qr(amount_idr) do
      case Req.post(request(), url: "/qrcode/create", json: %{amount: amount_idr}) do
        {:ok, %Req.Response{status: status, body: body}} ->
          response = normalize_response(status, body)
          maybe_log_create_qr_body(body)
          log_create_qr_response(status, body, response)
          response

        {:error, %Req.TransportError{} = exception} ->
          Logger.warning("Mayar create_qr network error: #{exception_message(exception)}")
          {:error, :network_error}

        {:error, exception} ->
          Logger.warning("Mayar create_qr upstream error: #{exception_message(exception)}")
          {:error, :upstream_error}
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

    defp inspect_body(body) do
      body
      |> redact_body()
      |> inspect(limit: 20, printable_limit: 2_000)
    end

    defp redact_body(%{"data" => data} = body) when is_map(data) do
      redacted_data =
        Enum.reduce(["url", "qrImageUrl", "qr_image_url"], data, fn key, acc ->
          Map.replace(acc, key, "[redacted]")
        end)
        |> redact_qr_fields()

      Map.put(body, "data", redacted_data)
    end

    defp redact_body(body), do: body

    defp redact_qr_fields(data) when is_map(data) do
      Enum.reduce(Map.keys(data), data, fn
        key, acc when is_binary(key) ->
          if String.contains?(String.downcase(key), "qr") do
            Map.put(acc, key, "[redacted]")
          else
            acc
          end

        _key, acc ->
          acc
      end)
    end

    defp log_create_qr_response(status, body, {:ok, %DynamicQr{} = dynamic_qr}) do
      Logger.info(
        "Mayar create_qr ok status=#{status} mayar_transaction_id=#{dynamic_qr.mayar_transaction_id} id_source=#{transaction_id_source(body)} amount=#{dynamic_qr.amount} expires_at=#{format_expires_at(dynamic_qr.expires_at)}"
      )
    end

    defp log_create_qr_response(_status, _body, {:error, :unauthorized}),
      do: Logger.warning("Mayar create_qr failed reason=unauthorized")

    defp log_create_qr_response(_status, _body, {:error, :rate_limited}),
      do: Logger.warning("Mayar create_qr failed reason=rate_limited")

    defp log_create_qr_response(status, body, {:error, reason}) do
      Logger.warning(
        "Mayar create_qr failed status=#{status} reason=#{inspect(reason)} body=#{inspect_body(body)}"
      )
    end

    defp transaction_id_source(%{"data" => data}) when is_map(data) do
      case fetch_binary(data, ["transactionId", "id"]) do
        {:ok, _value} ->
          "response"

        :error ->
          transaction_id_source_from_url(data)
      end
    end

    defp transaction_id_source(_body), do: "unknown"

    defp transaction_id_source_from_url(data) do
      with {:ok, url} <- fetch_binary(data, ["url", "qrImageUrl", "qr_image_url"]),
           normalized_url <- normalize_qr_image_url(url),
           {:ok, _transaction_id} <- extract_transaction_id_from_url(normalized_url) do
        "url"
      else
        _ -> "unknown"
      end
    end

    defp maybe_log_create_qr_body(body) do
      if Application.get_env(:donatex, :mayar_log_create_qr_body, false) do
        Logger.debug("Mayar create_qr raw_body=#{inspect_body(body)}")
      end
    end

    defp format_expires_at(nil), do: "nil"

    defp format_expires_at(%DateTime{} = datetime) do
      DateTime.to_iso8601(datetime)
    end

    defp format_expires_at(other), do: inspect(other)

    defp exception_message(exception) do
      Exception.message(exception)
    rescue
      _ -> inspect(exception)
    end

    defp build_dynamic_qr(%{"data" => data}) when is_map(data) do
      with {:ok, qr_image_url} <- fetch_binary(data, ["url", "qrImageUrl", "qr_image_url"]),
           qr_image_url <- normalize_qr_image_url(qr_image_url),
           :ok <- validate_qr_image_url(qr_image_url),
           {:ok, mayar_transaction_id} <- fetch_mayar_transaction_id(data, qr_image_url),
           {:ok, amount} <- fetch_positive_integer(data, ["amount"]),
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

    defp fetch_mayar_transaction_id(data, qr_image_url) do
      case fetch_binary(data, ["transactionId", "id"]) do
        {:ok, mayar_transaction_id} ->
          {:ok, mayar_transaction_id}

        :error ->
          extract_transaction_id_from_url(qr_image_url)
      end
    end

    defp extract_transaction_id_from_url(url) when is_binary(url) do
      case URI.parse(url) do
        %URI{path: path} when is_binary(path) and byte_size(path) > 0 ->
          transaction_id =
            path
            |> Path.basename()
            |> Path.rootname()

          if uuid?(transaction_id) do
            {:ok, transaction_id}
          else
            :error
          end

        _other ->
          :error
      end
    end

    defp extract_transaction_id_from_url(_url), do: :error

    defp parse_expires_at(nil), do: {:ok, nil}
    defp parse_expires_at(""), do: {:ok, nil}

    defp parse_expires_at(expires_at) when is_binary(expires_at) do
      case DateTime.from_iso8601(expires_at) do
        {:ok, parsed, _offset} -> {:ok, parsed}
        _error -> :error
      end
    end

    defp parse_expires_at(expires_at) when is_integer(expires_at) and expires_at > 0 do
      expires_at
      |> normalize_unix_timestamp()
      |> DateTime.from_unix()
      |> case do
        {:ok, parsed} -> {:ok, parsed}
        {:error, _reason} -> :error
      end
    end

    defp parse_expires_at(_expires_at), do: :error

    defp normalize_unix_timestamp(timestamp)
         when is_integer(timestamp) and timestamp > 4_000_000_000 do
      div(timestamp, 1_000)
    end

    defp normalize_unix_timestamp(timestamp), do: timestamp

    defp present_binary(value) when is_binary(value) do
      case String.trim(value) do
        "" -> nil
        trimmed -> trimmed
      end
    end

    defp present_binary(_value), do: nil

    defp positive_integer(value) when is_integer(value) and value > 0, do: value

    defp positive_integer(value) when is_binary(value) do
      value
      |> String.trim()
      |> Integer.parse()
      |> case do
        {integer, ""} when integer > 0 -> integer
        _ -> nil
      end
    end

    defp positive_integer(_value), do: nil

    defp normalize_qr_image_url(url) when is_binary(url) do
      url
      |> String.trim()
      |> String.trim("`")
    end

    defp normalize_qr_image_url(url), do: url

    defp allow_insecure_qr_image_url? do
      Application.get_env(:donatex, :allow_insecure_qr_image_url, false)
    end

    defp validate_qr_image_url(url) when is_binary(url) do
      cond do
        https_url?(url) -> :ok
        data_image_url?(url) -> :ok
        allowed_insecure_http_url?(url) -> :ok
        true -> :error
      end
    end

    defp validate_qr_image_url(_url), do: :error

    defp https_url?(<<"https://", _rest::binary>>), do: true
    defp https_url?(_url), do: false

    defp data_image_url?(<<"data:image/png;base64,", _rest::binary>>), do: true
    defp data_image_url?(<<"data:image/jpeg;base64,", _rest::binary>>), do: true
    defp data_image_url?(<<"data:image/webp;base64,", _rest::binary>>), do: true
    defp data_image_url?(_url), do: false

    defp allowed_insecure_http_url?(<<"http://", _rest::binary>> = http_url) do
      allow_insecure_qr_image_url?() and localhost_url?(http_url)
    end

    defp allowed_insecure_http_url?(_url), do: false

    defp localhost_url?(url) do
      case URI.parse(url) do
        %URI{host: host} when host in ["localhost", "127.0.0.1", "0.0.0.0"] -> true
        _ -> false
      end
    end

    defp uuid?(value) when is_binary(value) do
      Regex.match?(@uuid_regex, value)
    end
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
