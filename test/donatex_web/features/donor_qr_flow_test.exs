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
    |> visit(~p"/")
    |> fill_in("Nama kamu", with: "Riza")
    |> choose("Great", exact: false)
    |> check("Tambah tip apresiasi", exact: false)
    |> choose("Rp 10.000", exact: false)
    |> click_button("Kirim feedback + tip")
    |> assert_has("h1", "Scan QRIS untuk Apresiasi")
    |> assert_has(
      "p",
      "Buka aplikasi ewallet atau ebanking kesayangan kamu untuk scan QRIS."
    )
    |> assert_has(
      "[role='status'][aria-live='polite']",
      "Menunggu konfirmasi pembayaran"
    )
    |> unwrap(fn view ->
      html = Phoenix.LiveViewTest.render(view)
      assert html =~ "https://example.invalid/qr/10000"
      html
    end)

    donation = Repo.get_by!(Donation, mayar_transaction_id: "tx-donate-1")
    assert donation.status == "pending"
    assert donation.donor_name == "Riza"
    assert donation.reaction == "great"
    assert donation.amount == 10_000
  end

  test "preserves default tip amount after editing while appreciation is collapsed", %{
    conn: conn
  } do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/hl/v1/qrcode/create"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"amount" => 10_000}

      Req.Test.json(conn, %{
        "statusCode" => 200,
        "messages" => "Success",
        "data" => %{
          "transactionId" => "tx-donate-preserve-amount",
          "amount" => 10_000,
          "url" => "https://example.invalid/qr/preserve-amount"
        }
      })
    end)

    conn
    |> visit(~p"/")
    |> fill_in("Nama kamu", with: "Riza")
    |> choose("Great", exact: false)
    |> check("Tambah tip apresiasi", exact: false)
    |> click_button("Kirim feedback + tip")
    |> assert_has("h1", "Scan QRIS untuk Apresiasi")

    donation = Repo.get_by!(Donation, mayar_transaction_id: "tx-donate-preserve-amount")
    assert donation.status == "pending"
    assert donation.amount == 10_000
  end

  test "preserves non-default tip amount after collapsing appreciation", %{conn: conn} do
    Req.Test.expect(__MODULE__, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"amount" => 25_000}

      Req.Test.json(conn, %{
        "statusCode" => 200,
        "messages" => "Success",
        "data" => %{
          "transactionId" => "tx-donate-preserve-25k",
          "amount" => 25_000,
          "url" => "https://example.invalid/qr/preserve-25k"
        }
      })
    end)

    conn
    |> visit(~p"/")
    |> fill_in("Nama kamu", with: "Riza")
    |> choose("Great", exact: false)
    |> check("Tambah tip apresiasi", exact: false)
    |> choose("Rp 25.000", exact: false)
    |> uncheck("Tambah tip apresiasi", exact: false)
    |> check("Tambah tip apresiasi", exact: false)
    |> click_button("Kirim feedback + tip")
    |> assert_has("h1", "Scan QRIS untuk Apresiasi")

    donation = Repo.get_by!(Donation, mayar_transaction_id: "tx-donate-preserve-25k")
    assert donation.status == "pending"
    assert donation.amount == 25_000
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
      |> visit(~p"/")
      |> fill_in("Nama kamu", with: "Riza")
      |> choose("Good", exact: false)
      |> check("Tambah tip apresiasi", exact: false)
      |> choose("Rp 10.000", exact: false)
      |> click_button("Kirim feedback + tip")
      |> assert_has("h1", "Scan QRIS untuk Apresiasi")

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
    |> assert_has("h1", "Terima kasih! Pesan dan tip Anda telah tersimpan.")
    |> assert_has(
      "section[role='status'][aria-live='polite']",
      "Terima kasih! Pesan dan tip Anda telah tersimpan."
    )

    session
    |> click_button("Kirim lagi")
    |> assert_has("h1", donor_hero_headline())
  end

  test "webhook correlation uses the QR image URL UUID when transaction id is omitted from QR create response",
       %{
         conn: conn
       } do
    qr_url =
      "https://media.mayar.club/images/resized/480/ce50314d-52fe-4cfe-8488-0ccc8a0393a8.png"

    # The UUID extracted from the QR image URL becomes the transaction ID
    transaction_id = "ce50314d-52fe-4cfe-8488-0ccc8a0393a8"

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/hl/v1/qrcode/create"

      Req.Test.json(conn, %{
        "statusCode" => 200,
        "messages" => "Success",
        "data" => %{
          "amount" => 25_000,
          "url" => qr_url
        }
      })
    end)

    session =
      conn
      |> visit(~p"/")
      |> fill_in("Nama kamu", with: "Riza")
      |> choose("Okay", exact: false)
      |> check("Tambah tip apresiasi", exact: false)
      |> choose("Rp 25.000", exact: false)
      |> click_button("Kirim feedback + tip")
      |> assert_has("h1", "Scan QRIS untuk Apresiasi")

    donation = Repo.get_by!(Donation, mayar_transaction_id: transaction_id)
    assert donation.mayar_transaction_id == transaction_id

    conn
    |> recycle()
    |> put_req_header("accept", "application/json")
    |> post(~p"/webhooks/mayar/#{Config.mayar_webhook_token()}", %{
      "event" => "payment.received",
      "data" => %{
        "id" => donation.mayar_transaction_id,
        "amount" => donation.amount,
        "customerName" => donation.donor_name,
        "transactionStatus" => "paid"
      }
    })

    session
    |> assert_has("h1", "Terima kasih! Pesan dan tip Anda telah tersimpan.")
  end

  test "back from the QR screen resets the donor form", %{conn: conn} do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "statusCode" => 200,
        "messages" => "Success",
        "data" => %{
          "transactionId" => "tx-donate-back",
          "amount" => 10_000,
          "url" => "https://example.invalid/qr/back",
          "expiresAt" => "2030-01-01T00:00:00Z"
        }
      })
    end)

    conn
    |> visit(~p"/")
    |> fill_in("Nama kamu", with: "Riza")
    |> choose("Great", exact: false)
    |> check("Tambah tip apresiasi", exact: false)
    |> choose("Rp 10.000", exact: false)
    |> click_button("Kirim feedback + tip")
    |> assert_has("h1", "Scan QRIS untuk Apresiasi")
    |> assert_has("#payment-expiry")
    |> click_button("Kembali ke form")
    |> assert_has("h1", donor_hero_headline())
    |> refute_has("#amount-options")
    |> assert_has("#donation-form button[type='submit']", "Kirim feedback")
    |> unwrap(fn view ->
      html = Phoenix.LiveViewTest.render(view)
      refute html =~ ~s(value="Riza")
      refute html =~ "https://example.invalid/qr/back"
      html
    end)
  end

  test "shows an error and stays on the form when QR creation fails", %{conn: conn} do
    Req.Test.expect(__MODULE__, fn conn ->
      Plug.Conn.send_resp(conn, 401, "unauthorized")
    end)

    capture_log(fn ->
      conn
      |> visit(~p"/")
      |> fill_in("Nama kamu", with: "Riza")
      |> choose("Good", exact: false)
      |> check("Tambah tip apresiasi", exact: false)
      |> choose("Rp 10.000", exact: false)
      |> click_button("Kirim feedback + tip")
      |> assert_has("h1", donor_hero_headline())
      |> unwrap(fn view ->
        html = Phoenix.LiveViewTest.render(view)
        assert html =~ ~s(value="Riza")
        assert html =~ "QR belum bisa dibuat sekarang"
        html
      end)
    end)
  end

  test "shows an error and stays on the form when QR creation succeeds but donation persistence fails",
       %{
         conn: conn
       } do
    mayar_transaction_id = String.duplicate("x", 200)

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "statusCode" => 200,
        "messages" => "Success",
        "data" => %{
          "transactionId" => mayar_transaction_id,
          "amount" => 10_000,
          "url" => "https://example.invalid/qr/persist-failed"
        }
      })
    end)

    capture_log(fn ->
      conn
      |> visit(~p"/")
      |> fill_in("Nama kamu", with: "Riza")
      |> choose("Good", exact: false)
      |> check("Tambah tip apresiasi", exact: false)
      |> choose("Rp 10.000", exact: false)
      |> click_button("Kirim feedback + tip")
      |> assert_has("h1", donor_hero_headline())
      |> unwrap(fn view ->
        html = Phoenix.LiveViewTest.render(view)
        assert html =~ "Tip belum bisa disimpan"
        refute html =~ "Donasi belum bisa disimpan"
        refute html =~ "https://example.invalid/qr/persist-failed"
        html
      end)
    end)

    assert Repo.get_by(Donation, mayar_transaction_id: mayar_transaction_id) == nil
  end

  defp verify_req_expectations!(_context) do
    Req.Test.verify_on_exit!()
  end

  defp restore_env(key, nil), do: Application.delete_env(:donatex, key)
  defp restore_env(key, value), do: Application.put_env(:donatex, key, value)
end
