defmodule Donatex.Mayar.ClientTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Donatex.Mayar.Client

  setup :verify_req_expectations!

  setup do
    original_mayar = Application.get_env(:donatex, :mayar)
    original_impl = Application.get_env(:donatex, :mayar_client_impl)
    original_req_options = Application.get_env(:donatex, :mayar_req_options)

    Application.put_env(:donatex, :mayar,
      base_url: "https://api.example.test/hl/v1",
      api_key: "mayar_test_key",
      webhook_token: "mayar_webhook_test_token"
    )

    Application.delete_env(:donatex, :mayar_client_impl)
    Application.put_env(:donatex, :mayar_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      restore_env(:mayar, original_mayar)
      restore_env(:mayar_client_impl, original_impl)
      restore_env(:mayar_req_options, original_req_options)
    end)

    :ok
  end

  test "create_qr/1 validates amount" do
    assert {:error, :invalid_amount} = Client.create_qr(0)
    assert {:error, :invalid_amount} = Client.create_qr(-1)
    assert {:error, :invalid_amount} = Client.create_qr("10_000")
  end

  test "create_qr/1 posts the amount with bearer auth and normalizes the response" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/hl/v1/qrcode/create"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer mayar_test_key"]

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"amount" => 10_000}

      Req.Test.json(conn, %{
        "statusCode" => 200,
        "messages" => "Success",
        "data" => %{
          "id" => "txn_test_10000",
          "amount" => 10_000,
          "url" => "https://example.invalid/qr/10000"
        }
      })
    end)

    assert {:ok,
            %Client.DynamicQr{
              mayar_transaction_id: "txn_test_10000",
              amount: 10_000,
              qr_image_url: "https://example.invalid/qr/10000",
              expires_at: nil
            }} = Client.create_qr(10_000)
  end

  test "create_qr/1 resolves mayar_transaction_id from QR image URL when the response omits it" do
    qr_url =
      "`https://media.mayar.club/images/resized/480/ce50314d-52fe-4cfe-8488-0ccc8a0393a8.png`"

    # The UUID extracted from the URL
    resolved_transaction_id = "ce50314d-52fe-4cfe-8488-0ccc8a0393a8"

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/hl/v1/qrcode/create"

      Req.Test.json(conn, %{
        "data" => %{
          "amount" => 25_000,
          "url" => qr_url
        }
      })
    end)

    # Should NOT call unpaid transactions - URL extraction should succeed
    assert {:ok,
            %Client.DynamicQr{
              mayar_transaction_id: ^resolved_transaction_id,
              amount: 25_000,
              qr_image_url:
                "https://media.mayar.club/images/resized/480/ce50314d-52fe-4cfe-8488-0ccc8a0393a8.png",
              expires_at: nil
            }} = Client.create_qr(25_000)
  end

  test "create_qr/1 fails closed when it cannot resolve a unique Mayar transaction id" do
    # Use a URL without a valid UUID pattern so URL extraction fails,
    # forcing the unpaid transactions fallback which also fails due to ambiguity
    qr_url_without_uuid = "https://media.mayar.club/images/qr/static.png"

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "data" => %{
          "amount" => 25_000,
          "url" => qr_url_without_uuid
        }
      })
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "data" => [
          %{
            "id" => "first-transaction-id",
            "amount" => 25_000,
            "createdAt" => System.system_time(:millisecond)
          },
          %{
            "id" => "second-transaction-id",
            "amount" => 25_000,
            "createdAt" => System.system_time(:millisecond)
          }
        ]
      })
    end)

    capture_log(fn ->
      assert {:error,
              {:unexpected_response,
               %{
                 "data" => %{
                   "amount" => 25_000,
                   "url" => ^qr_url_without_uuid
                 }
               }}} = Client.create_qr(25_000)
    end)
  end

  test "create_qr/1 accepts alternate response field names and parses expires_at" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "data" => %{
          "transactionId" => "txn_test_20000",
          "amount" => "20000",
          "qrImageUrl" => "https://example.invalid/qr/20000",
          "expiresAt" => "2026-05-02T10:00:00Z"
        }
      })
    end)

    assert {:ok,
            %Client.DynamicQr{
              mayar_transaction_id: "txn_test_20000",
              amount: 20_000,
              qr_image_url: "https://example.invalid/qr/20000",
              expires_at: %DateTime{}
            }} = Client.create_qr(20_000)
  end

  test "create_qr/1 parses unix timestamp expiry in seconds or milliseconds" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "data" => %{
          "transactionId" => "txn_test_expiry_epoch",
          "amount" => 30_000,
          "url" => "https://example.invalid/qr/30000",
          "expiresAt" => 1_800_000_000_000
        }
      })
    end)

    assert {:ok, %Client.DynamicQr{expires_at: %DateTime{} = expires_at}} =
             Client.create_qr(30_000)

    assert expires_at.year == 2027
  end

  test "create_qr/1 maps 401 responses to unauthorized" do
    Req.Test.expect(__MODULE__, fn conn ->
      Plug.Conn.send_resp(conn, 401, "unauthorized")
    end)

    capture_log(fn ->
      assert {:error, :unauthorized} = Client.create_qr(10_000)
    end)
  end

  test "create_qr/1 maps 429 responses to rate_limited" do
    Req.Test.expect(__MODULE__, fn conn ->
      Plug.Conn.send_resp(conn, 429, "too many requests")
    end)

    capture_log(fn ->
      assert {:error, :rate_limited} = Client.create_qr(10_000)
    end)
  end

  test "create_qr/1 maps transport failures to network_error" do
    Req.Test.expect(__MODULE__, &Req.Test.transport_error(&1, :econnrefused))

    capture_log(fn ->
      assert {:error, :network_error} = Client.create_qr(10_000)
    end)
  end

  test "create_qr/1 returns unexpected_response when required fields are missing" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"data" => %{"amount" => 10_000}})
    end)

    capture_log(fn ->
      assert {:error, {:unexpected_response, %{"data" => %{"amount" => 10_000}}}} =
               Client.create_qr(10_000)
    end)
  end

  test "create_qr/1 returns unexpected_response when qr_image_url is not an https or data:image URL" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "data" => %{
          "transactionId" => "txn_test_bad_url",
          "amount" => 10_000,
          "url" => "javascript:alert(1)"
        }
      })
    end)

    capture_log(fn ->
      assert {:error,
              {:unexpected_response,
               %{
                 "data" => %{
                   "amount" => 10_000,
                   "transactionId" => "txn_test_bad_url",
                   "url" => "javascript:alert(1)"
                 }
               }}} = Client.create_qr(10_000)
    end)
  end

  defp verify_req_expectations!(_context) do
    Req.Test.verify_on_exit!()
  end

  defp restore_env(key, nil), do: Application.delete_env(:donatex, key)
  defp restore_env(key, value), do: Application.put_env(:donatex, key, value)
end
