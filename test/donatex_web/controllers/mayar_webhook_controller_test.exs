defmodule DonatexWeb.MayarWebhookControllerTest do
  use DonatexWeb.ConnCase, async: true

  alias Donatex.Config
  alias Donatex.Donations
  alias Donatex.Donations.Donation
  alias Donatex.Repo

  test "marks donation as paid and broadcasts only once", %{conn: conn} do
    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")

    assert {:ok, %Donation{} = donation} =
             Donations.create_pending_donation(%{
               mayar_transaction_id: "tx-webhook-1",
               donor_name: "Donor",
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

  test "treats SUCCESS as paid for donation confirmation", %{conn: conn} do
    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")

    assert {:ok, %Donation{} = donation} =
             Donations.create_pending_donation(%{
               mayar_transaction_id: "tx-webhook-success-1",
               donor_name: "Donor",
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
end
