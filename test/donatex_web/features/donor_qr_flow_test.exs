defmodule DonatexWeb.DonorQrFlowTest do
  use DonatexWeb.ConnCase, async: false

  import ExUnit.CaptureLog

  alias Donatex.Config
  alias Donatex.Donations.Donation
  alias Donatex.Repo

  setup :verify_req_expectations!

  setup do
    original_mayar = Application.get_env(:donatex, :mayar)
    original_impl = Application.get_env(:donatex, :mayar_client_impl)
    original_req_options = Application.get_env(:donatex, :mayar_req_options)

    Application.put_env(
      :donatex,
      :mayar,
      Keyword.put(original_mayar, :base_url, "https://api.example.test/hl/v1")
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

  test "submitting the donor form creates a pending donation and shows the QR", %{conn: conn} do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/hl/v1/qrcode/create"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"amount" => 10_000}

      Req.Test.json(conn, %{
        "statusCode" => 200,
        "messages" => "Success",
        "data" => %{
          "transactionId" => "tx-donate-1",
          "amount" => 10_000,
          "url" => "https://example.invalid/qr/10000"
        }
      })
    end)

    conn
    |> visit(~p"/donate")
    |> fill_in("Your name", with: "Riza")
    |> choose("Rp 10.000", exact: false)
    |> click_button("Create your QRIS")
    |> assert_has("h1", "Scan the QRIS")
    |> unwrap(fn view ->
      html = Phoenix.LiveViewTest.render(view)
      assert html =~ "https://example.invalid/qr/10000"
      html
    end)

    donation = Repo.get_by!(Donation, mayar_transaction_id: "tx-donate-1")
    assert donation.status == "pending"
    assert donation.donor_name == "Riza"
    assert donation.amount == 10_000
  end

  test "webhook confirmation transitions donor page to success and supports new donation", %{
    conn: conn
  } do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "statusCode" => 200,
        "messages" => "Success",
        "data" => %{
          "transactionId" => "tx-donate-2",
          "amount" => 10_000,
          "url" => "https://example.invalid/qr/20000"
        }
      })
    end)

    session =
      conn
      |> visit(~p"/donate")
      |> fill_in("Your name", with: "Riza")
      |> choose("Rp 10.000", exact: false)
      |> click_button("Create your QRIS")
      |> assert_has("h1", "Scan the QRIS")

    donation = Repo.get_by!(Donation, mayar_transaction_id: "tx-donate-2")

    conn
    |> recycle()
    |> put_req_header("accept", "application/json")
    |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
      "event" => "payment.received",
      "data" => %{
        "transactionId" => donation.mayar_transaction_id,
        "amount" => donation.amount,
        "customerName" => donation.donor_name,
        "transactionStatus" => "paid"
      }
    })

    session
    |> assert_has("h1", "Thank you for the support")

    session
    |> click_button("Make another donation")
    |> assert_has("h1", "Donate")
  end

  test "shows an error and stays on the form when QR creation fails", %{conn: conn} do
    Req.Test.expect(__MODULE__, fn conn ->
      Plug.Conn.send_resp(conn, 401, "unauthorized")
    end)

    capture_log(fn ->
      conn
      |> visit(~p"/donate")
      |> fill_in("Your name", with: "Riza")
      |> choose("Rp 10.000", exact: false)
      |> click_button("Create your QRIS")
      |> assert_has("h1", "Donate")
    end)
  end

  defp verify_req_expectations!(_context) do
    Req.Test.verify_on_exit!()
  end

  defp restore_env(key, nil), do: Application.delete_env(:donatex, key)
  defp restore_env(key, value), do: Application.put_env(:donatex, key, value)
end
