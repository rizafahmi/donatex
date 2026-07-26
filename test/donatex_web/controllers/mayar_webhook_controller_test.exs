defmodule DonatexWeb.MayarWebhookControllerTest do
  use DonatexWeb.ConnCase, async: false

  alias Donatex.Config
  alias Donatex.Donations
  alias Donatex.Donations.Donation
  alias Donatex.Repo

  defmodule TestStub do
    @behaviour Donatex.Mayar.Client.Impl
    def create_qr(_amount, _opts), do: {:error, :network_error}
    def lookup_transaction(_tx_id), do: {:error, :not_implemented}
  end

  defmodule LookupStub do
    @behaviour Donatex.Mayar.Client.Impl
    def create_qr(_amount, _opts), do: {:error, :network_error}

    # Match any tx-id that starts with 129 "c" chars (used by the update-fail test)
    def lookup_transaction(tx_id) when is_binary(tx_id) and byte_size(tx_id) >= 129 do
      {:ok, %{"data" => %{"originalTransactionId" => "original-tx-update-fail"}}}
    end

    def lookup_transaction(_tx_id), do: {:error, :not_implemented}
  end

  defmodule RaisingStub do
    @behaviour Donatex.Mayar.Client.Impl
    def create_qr(_amount, _opts), do: {:error, :network_error}

    # Simulates a programmer error (not a transport error) that must NOT
    # be silently swallowed by the bare rescue.
    def lookup_transaction("programmer-error-tx"), do: raise(KeyError, key: :bad_field)

    # Simulates a transient transport error that SHOULD be caught and
    # fall through to amount-fallback.
    def lookup_transaction("transport-error-tx") do
      raise Req.TransportError, reason: :timeout
    end

    def lookup_transaction(_tx_id), do: {:error, :not_implemented}
  end

  setup do
    original_impl = Application.get_env(:donatex, :mayar_client_impl)
    Application.put_env(:donatex, :mayar_client_impl, TestStub)

    on_exit(fn ->
      if original_impl do
        Application.put_env(:donatex, :mayar_client_impl, original_impl)
      else
        Application.delete_env(:donatex, :mayar_client_impl)
      end
    end)

    :ok
  end

  test "marks donation as paid and broadcasts only once", %{conn: conn} do
    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")

    assert {:ok, %Donation{} = donation} =
             Donations.create_pending_donation(%{
               mayar_transaction_id: "tx-webhook-1",
               donor_name: "Donor",
               reaction: "good",
               amount: 10_000
             })

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
        "event" => "payment.received",
        "data" => %{
          "transactionId" => "tx-webhook-1",
          "amount" => 10_000,
          "customerName" => "Donor",
          "transactionStatus" => "paid"
        }
      })

    assert json_response(conn, 200) == %{"ok" => true}

    assert %Donation{id: id, status: "paid"} = Repo.get!(Donation, donation.id)
    assert_received {:donation_paid, %{id: ^id, mayar_transaction_id: "tx-webhook-1"}}

    conn
    |> recycle()
    |> put_req_header("accept", "application/json")
    |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
      "event" => "payment.received",
      "data" => %{
        "transactionId" => "tx-webhook-1",
        "amount" => 10_000,
        "transactionStatus" => "paid"
      }
    })

    refute_receive {:donation_paid, _payload}, 50
  end

  test "concurrent paid webhooks for the same transaction broadcast only once", %{conn: _conn} do
    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")

    assert {:ok, %Donation{} = donation} =
             Donations.create_pending_donation(%{
               mayar_transaction_id: "tx-webhook-concurrent-1",
               donor_name: "Donor",
               reaction: "good",
               amount: 10_000
             })

    payload = %{
      "event" => "payment.received",
      "data" => %{
        "transactionId" => "tx-webhook-concurrent-1",
        "amount" => 10_000,
        "customerName" => "Donor",
        "transactionStatus" => "paid"
      }
    }

    token = Config.mayar_webhook_token()

    results =
      1..8
      |> Enum.map(fn _ ->
        Task.async(fn ->
          build_conn()
          |> put_req_header("accept", "application/json")
          |> post(~p"/webhooks/mayar/#{token}", payload)
        end)
      end)
      |> Enum.map(&Task.await(&1, 5_000))

    assert Enum.all?(results, fn result_conn ->
             json_response(result_conn, 200) == %{"ok" => true}
           end)

    assert %Donation{id: id, status: "paid"} = Repo.get!(Donation, donation.id)
    assert_receive {:donation_paid, %{id: ^id, mayar_transaction_id: "tx-webhook-concurrent-1"}}
    refute_receive {:donation_paid, _payload}, 50
  end

  test "treats SUCCESS as paid for donation confirmation", %{conn: conn} do
    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")

    assert {:ok, %Donation{} = donation} =
             Donations.create_pending_donation(%{
               mayar_transaction_id: "tx-webhook-success-1",
               donor_name: "Donor",
               reaction: "great",
               amount: 10_000
             })

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
        "event" => "payment.received",
        "data" => %{
          "transactionId" => "tx-webhook-success-1",
          "amount" => 10_000,
          "transactionStatus" => "SUCCESS"
        }
      })

    assert json_response(conn, 200) == %{"ok" => true}
    assert %Donation{id: id, status: "paid"} = Repo.get!(Donation, donation.id)
    assert_received {:donation_paid, %{id: ^id, mayar_transaction_id: "tx-webhook-success-1"}}
  end

  test "ignores webhook deliveries that are not marked as paid", %{conn: conn} do
    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")

    assert {:ok, %Donation{} = donation} =
             Donations.create_pending_donation(%{
               mayar_transaction_id: "tx-webhook-2",
               donor_name: "Donor",
               reaction: "ok",
               amount: 10_000
             })

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
        "event" => "payment.received",
        "data" => %{
          "transactionId" => "tx-webhook-2",
          "amount" => 10_000,
          "transactionStatus" => "pending"
        }
      })

    assert json_response(conn, 200) == %{"ok" => true}
    assert %Donation{status: "pending"} = Repo.get!(Donation, donation.id)
    refute_receive {:donation_paid, _payload}, 50
  end

  test "ignores webhook deliveries with amount mismatch", %{conn: conn} do
    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")

    assert {:ok, %Donation{} = donation} =
             Donations.create_pending_donation(%{
               mayar_transaction_id: "tx-webhook-3",
               donor_name: "Donor",
               reaction: "bad",
               amount: 10_000
             })

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
        "event" => "payment.received",
        "data" => %{
          "transactionId" => "tx-webhook-3",
          "amount" => 20_000,
          "transactionStatus" => "paid"
        }
      })

    assert json_response(conn, 200) == %{"ok" => true}
    assert %Donation{status: "pending"} = Repo.get!(Donation, donation.id)
    refute_receive {:donation_paid, _payload}, 50
  end

  test "accepts the alternate id field name for webhook correlation", %{conn: conn} do
    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")

    transaction_id = "ce50314d-52fe-4cfe-8488-0ccc8a0393a8"

    assert {:ok, %Donation{} = donation} =
             Donations.create_pending_donation(%{
               mayar_transaction_id: transaction_id,
               donor_name: "Donor",
               reaction: "good",
               amount: 25_000
             })

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
        "event" => "payment.received",
        "data" => %{
          "id" => transaction_id,
          "amount" => 25_000,
          "transactionStatus" => "paid"
        }
      })

    assert json_response(conn, 200) == %{"ok" => true}

    assert %Donation{id: id, status: "paid"} = Repo.get!(Donation, donation.id)
    assert_received {:donation_paid, %{id: ^id, mayar_transaction_id: ^transaction_id}}
  end

  test "rejects requests with invalid token before controller logic", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(~p"/webhooks/mayar/not-a-real-token", %{"event" => "payment.received"})

    assert response(conn, 404)
  end

  test "falls back to amount lookup when transaction ID differs (Mayar confirmation ID)", %{
    conn: conn
  } do
    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")

    # Mayar returns a different transaction ID in the QR URL vs what they send in webhook
    original_tx_id = "original-qr-tx-id-12345"
    confirmation_tx_id = "confirmation-tx-id-67890"

    assert {:ok, %Donation{} = donation} =
             Donations.create_pending_donation(%{
               mayar_transaction_id: original_tx_id,
               donor_name: "Maya",
               reaction: "great",
               amount: 15_000
             })

    # Mayar webhook sends the confirmation transaction ID (different from QR URL)
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
        "event" => "payment.received",
        "data" => %{
          "transactionId" => confirmation_tx_id,
          "amount" => 15_000,
          "customerName" => "Maya",
          "transactionStatus" => "paid"
        }
      })

    assert json_response(conn, 200) == %{"ok" => true}

    # Donation should be marked as paid and transaction ID updated
    updated_donation = Repo.get!(Donation, donation.id)
    assert updated_donation.status == "paid"
    assert updated_donation.mayar_transaction_id == confirmation_tx_id

    # Broadcast should have been sent with updated transaction ID
    assert_received {:donation_paid, %{id: id, mayar_transaction_id: ^confirmation_tx_id}}
    assert id == donation.id
  end

  test "returns 500 and does not broadcast when mark-paid DB fails", %{conn: conn} do
    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")

    # Insert a donation with status "sent" directly via Repo to bypass changeset
    # validations. mark_paid_with_change will return {:error, :invalid_state}
    # because the donation is not "pending" or "paid".
    donation =
      Repo.insert!(%Donation{
        id: Ecto.UUID.generate(),
        mayar_transaction_id: "tx-mark-paid-fail",
        donor_name: "Donor",
        reaction: "good",
        amount: 10_000,
        status: "sent",
        alerted: true,
        inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
        updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
        "event" => "payment.received",
        "data" => %{
          "transactionId" => donation.mayar_transaction_id,
          "amount" => 10_000,
          "transactionStatus" => "paid"
        }
      })

    assert response(conn, 500)
    assert %Donation{status: "sent"} = Repo.get!(Donation, donation.id)
    refute_receive {:donation_paid, _payload}, 50
  end

  test "returns 500 and does not broadcast when transaction ID update fails", %{
    conn: conn
  } do
    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")

    # The webhook sends a confirmation tx-id that differs from the original.
    # The Mayar lookup stub resolves it back to the original.
    # update_mayar_transaction_id will fail because the confirmation tx-id
    # exceeds the 128-char max length validation.
    long_confirmation_id = String.duplicate("c", 129)

    assert {:ok, %Donation{} = donation} =
             Donations.create_pending_donation(%{
               mayar_transaction_id: "original-tx-update-fail",
               donor_name: "Donor",
               reaction: "good",
               amount: 5_000
             })

    Application.put_env(:donatex, :mayar_client_impl, LookupStub)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
        "event" => "payment.received",
        "data" => %{
          "transactionId" => long_confirmation_id,
          "amount" => 5_000,
          "transactionStatus" => "paid"
        }
      })

    assert response(conn, 500)

    assert %Donation{status: "pending", mayar_transaction_id: "original-tx-update-fail"} =
             Repo.get!(Donation, donation.id)

    refute_receive {:donation_paid, _payload}, 50
  end

  test "programmer errors in Mayar lookup propagate (not swallowed into amount fallback)",
       %{conn: conn} do
    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")

    assert {:ok, %Donation{} = donation} =
             Donations.create_pending_donation(%{
               mayar_transaction_id: "original-programmer-error",
               donor_name: "Donor",
               reaction: "good",
               amount: 5_000
             })

    Application.put_env(:donatex, :mayar_client_impl, RaisingStub)

    assert_raise KeyError, fn ->
      conn
      |> put_req_header("accept", "application/json")
      |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
        "event" => "payment.received",
        "data" => %{
          "transactionId" => "programmer-error-tx",
          "amount" => 5_000,
          "transactionStatus" => "paid"
        }
      })
    end

    # Donation must not have been marked paid by a silent amount-fallback
    assert %Donation{status: "pending"} = Repo.get!(Donation, donation.id)
    refute_receive {:donation_paid, _payload}, 50
  end

  test "transport errors in Mayar lookup are caught and fall through to amount fallback",
       %{conn: conn} do
    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")

    assert {:ok, %Donation{} = donation} =
             Donations.create_pending_donation(%{
               mayar_transaction_id: "original-transport-error",
               donor_name: "Donor",
               reaction: "good",
               amount: 5_000
             })

    Application.put_env(:donatex, :mayar_client_impl, RaisingStub)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
        "event" => "payment.received",
        "data" => %{
          "transactionId" => "transport-error-tx",
          "amount" => 5_000,
          "transactionStatus" => "paid"
        }
      })

    # Transport error is caught → falls through to amount fallback → marks paid
    assert json_response(conn, 200) == %{"ok" => true}
    assert %Donation{status: "paid"} = Repo.get!(Donation, donation.id)
    assert_received {:donation_paid, %{id: id}} when id == donation.id
  end

  test "malformed non-map webhook data still returns 200", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
        "event" => "payment.received",
        "data" => "malformed"
      })

    assert json_response(conn, 200) == %{"ok" => true}
  end

  test "redacts QR-containing keys from webhook payload logs", %{conn: conn} do
    import ExUnit.CaptureLog

    # Build a webhook payload with QR-related keys that are NOT in the
    # hardcoded drop list. The redaction must catch any key containing "qr".
    qr_url = "https://media.mayar.club/images/resized/480/secret-qr-asset.png"
    top_level_secret = "top-level-qr-secret"
    nested_secret = "nested-qr-secret"

    original_level = Logger.level()
    Logger.configure(level: :info)

    logs =
      capture_log(fn ->
        conn
        |> put_req_header("accept", "application/json")
        |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
          "event" => "payment.received",
          "qrisPayload" => top_level_secret,
          "data" => %{
            "transactionId" => "tx-redaction-test",
            "amount" => 5_000,
            "transactionStatus" => "paid",
            "qrCodeUrl" => qr_url,
            "qrImageData" => "data:image/png;base64,abc123",
            "url" => qr_url,
            "metadata" => [%{"details" => %{"nestedQrToken" => nested_secret}}]
          }
        })
      end)

    Logger.configure(level: original_level)

    # The actual QR URL must never appear in logs
    refute logs =~ qr_url
    refute logs =~ top_level_secret
    refute logs =~ nested_secret
    # Redacted placeholders should be present instead
    assert logs =~ "[redacted]"
  end

  test "amount fallback fails closed when multiple pending donations share the same amount", %{
    conn: conn
  } do
    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")

    {:ok, _first} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-amb-a",
        donor_name: "Alice",
        reaction: "good",
        amount: 12_000
      })

    {:ok, _second} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-amb-b",
        donor_name: "Bob",
        reaction: "ok",
        amount: 12_000
      })

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
        "event" => "payment.received",
        "data" => %{
          "transactionId" => "tx-confirmation-amb",
          "amount" => 12_000,
          "transactionStatus" => "paid"
        }
      })

    assert json_response(conn, 200) == %{"ok" => true}

    # Neither donation should be marked paid
    assert %Donation{status: "pending"} = Repo.get_by!(Donation, mayar_transaction_id: "tx-amb-a")
    assert %Donation{status: "pending"} = Repo.get_by!(Donation, mayar_transaction_id: "tx-amb-b")
    refute_receive {:donation_paid, _payload}, 50
  end

  test "amount fallback disambiguates by donor_name", %{conn: conn} do
    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")

    {:ok, _other} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-disamb-other",
        donor_name: "Alice",
        reaction: "good",
        amount: 18_000
      })

    {:ok, target} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-disamb-target",
        donor_name: "Charlie",
        reaction: "ok",
        amount: 18_000
      })

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
        "event" => "payment.received",
        "data" => %{
          "transactionId" => "tx-confirmation-disamb",
          "amount" => 18_000,
          "customerName" => "Charlie",
          "transactionStatus" => "paid"
        }
      })

    assert json_response(conn, 200) == %{"ok" => true}

    # Only the matching donation should be paid
    assert %Donation{status: "paid", mayar_transaction_id: "tx-confirmation-disamb"} =
             Repo.get!(Donation, target.id)

    assert %Donation{status: "pending"} =
             Repo.get_by!(Donation, mayar_transaction_id: "tx-disamb-other")

    assert_received {:donation_paid, %{id: id, mayar_transaction_id: "tx-confirmation-disamb"}}
    assert id == target.id
  end

  test "amount fallback logs orphan payment when no donation matches", %{conn: conn} do
    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
        "event" => "payment.received",
        "data" => %{
          "transactionId" => "tx-orphan-no-match",
          "amount" => 77_777,
          "transactionStatus" => "paid"
        }
      })

    assert json_response(conn, 200) == %{"ok" => true}
    refute_receive {:donation_paid, _payload}, 50
  end

  test "amount fallback claims the unique pending donation and broadcasts once", %{conn: conn} do
    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")

    {:ok, donation} =
      Donations.create_pending_donation(%{
        mayar_transaction_id: "tx-unique-fallback",
        donor_name: "Donor",
        reaction: "great",
        amount: 22_000
      })

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
        "event" => "payment.received",
        "data" => %{
          "transactionId" => "tx-confirmation-unique",
          "amount" => 22_000,
          "customerName" => "Donor",
          "transactionStatus" => "paid"
        }
      })

    assert json_response(conn, 200) == %{"ok" => true}

    updated = Repo.get!(Donation, donation.id)
    assert updated.status == "paid"
    assert updated.mayar_transaction_id == "tx-confirmation-unique"

    assert_received {:donation_paid, %{id: id, mayar_transaction_id: "tx-confirmation-unique"}}
    assert id == donation.id

    # Duplicate delivery does not rebroadcast
    conn
    |> recycle()
    |> put_req_header("accept", "application/json")
    |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
      "event" => "payment.received",
      "data" => %{
        "transactionId" => "tx-confirmation-unique",
        "amount" => 22_000,
        "transactionStatus" => "paid"
      }
    })

    refute_receive {:donation_paid, _payload}, 50
  end
end
