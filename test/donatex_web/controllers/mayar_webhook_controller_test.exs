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

  test "falls back to amount lookup when transaction ID differs and donor_name disambiguates", %{
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

    # Donation should be marked as paid and transaction ID updated atomically
    updated_donation = Repo.get!(Donation, donation.id)
    assert updated_donation.status == "paid"
    assert updated_donation.mayar_transaction_id == confirmation_tx_id

    # Broadcast should have been sent with updated transaction ID
    assert_received {:donation_paid, %{id: id, mayar_transaction_id: ^confirmation_tx_id}}
    assert id == donation.id
  end

  test "rejects amount fallback when multiple pending share same amount without donor_name", %{
    conn: conn
  } do
    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")

    assert {:ok, %Donation{} = _alice} =
             Donations.create_pending_donation(%{
               mayar_transaction_id: "tx-ambiguous-a",
               donor_name: "Alice",
               reaction: "great",
               amount: 10_000
             })

    assert {:ok, %Donation{} = _bob} =
             Donations.create_pending_donation(%{
               mayar_transaction_id: "tx-ambiguous-b",
               donor_name: "Bob",
               reaction: "good",
               amount: 10_000
             })

    # Webhook arrives with a different confirmation ID but no donor_name to disambiguate
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
        "event" => "payment.received",
        "data" => %{
          "transactionId" => "unknown-confirmation-tx",
          "amount" => 10_000,
          "transactionStatus" => "paid"
        }
      })

    # Still returns 200 (webhook is idempotent)
    assert json_response(conn, 200) == %{"ok" => true}

    # Neither donation should be marked paid — fail-closed
    assert Repo.get_by!(Donation, mayar_transaction_id: "tx-ambiguous-a").status == "pending"
    assert Repo.get_by!(Donation, mayar_transaction_id: "tx-ambiguous-b").status == "pending"

    # No alert broadcast
    refute_receive {:donation_paid, _payload}, 50
  end

  test "amount fallback disambiguates with donor_name when multiple pending share same amount",
       %{conn: conn} do
    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")

    assert {:ok, %Donation{} = alice} =
             Donations.create_pending_donation(%{
               mayar_transaction_id: "tx-name-amb-a",
               donor_name: "Alice",
               reaction: "great",
               amount: 10_000
             })

    assert {:ok, %Donation{} = _bob} =
             Donations.create_pending_donation(%{
               mayar_transaction_id: "tx-name-amb-b",
               donor_name: "Bob",
               reaction: "good",
               amount: 10_000
             })

    confirmation_tx_id = "confirmed-by-name-123"

    # Webhook with donor_name "Alice" disambiguates
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
        "event" => "payment.received",
        "data" => %{
          "transactionId" => confirmation_tx_id,
          "amount" => 10_000,
          "customerName" => "Alice",
          "transactionStatus" => "paid"
        }
      })

    assert json_response(conn, 200) == %{"ok" => true}

    # Alice should be paid, Bob still pending
    updated_alice = Repo.get!(Donation, alice.id)
    assert updated_alice.status == "paid"
    assert updated_alice.mayar_transaction_id == confirmation_tx_id

    assert Repo.get_by!(Donation, mayar_transaction_id: "tx-name-amb-b").status == "pending"

    # Exactly one broadcast
    assert_received {:donation_paid,
                     %{id: id, mayar_transaction_id: ^confirmation_tx_id, donor_name: "Alice"}}

    assert id == alice.id
    refute_receive {:donation_paid, _payload}, 50
  end
end
