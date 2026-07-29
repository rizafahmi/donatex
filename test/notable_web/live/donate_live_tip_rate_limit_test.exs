defmodule NotableWeb.DonateLiveTipRateLimitTest do
  use NotableWeb.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import Plug.Test, only: [put_peer_data: 2]

  alias Notable.Donations.Donation
  alias Notable.Repo
  alias Notable.SubmissionLimiter

  setup :verify_req_expectations!

  setup do
    SubmissionLimiter.reset()

    original_mayar = Application.get_env(:notable, :mayar)
    original_impl = Application.get_env(:notable, :mayar_client_impl)
    original_req_options = Application.get_env(:notable, :mayar_req_options)

    Application.put_env(
      :notable,
      :mayar,
      Keyword.put(original_mayar, :base_url, "https://api.example.test/hl/v1")
    )

    Application.delete_env(:notable, :mayar_client_impl)
    Application.put_env(:notable, :mayar_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      restore_env(:mayar, original_mayar)
      restore_env(:mayar_client_impl, original_impl)
      restore_env(:mayar_req_options, original_req_options)
    end)

    :ok
  end

  test "blocks a second tip from the same IP within 10 seconds without calling Mayar again",
       %{conn: conn} do
    conn = put_peer_data(conn, %{address: {203, 0, 113, 27}, port: 44_327, ssl_cert: nil})

    # Exactly one Mayar create_qr call expected for the whole test.
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "statusCode" => 200,
        "messages" => "Success",
        "data" => %{
          "transactionId" => "tx-tip-rate-1",
          "amount" => 10_000,
          "url" => "https://example.invalid/qr/tip-rate-1"
        }
      })
    end)

    {:ok, view, _html} = live(conn, ~p"/")

    tip_params = %{
      "donation_form" => %{
        "donor_name" => "Rate Limited Tip",
        "reaction" => "good",
        "message" => "",
        "show_appreciation" => "true",
        "amount_option" => "10000"
      }
    }

    html = render_submit(view, "submit_feedback", tip_params)
    assert html =~ "Scan QRIS untuk Apresiasi"

    render_click(view, "new_donation", %{})

    html = render_submit(view, "submit_feedback", tip_params)
    assert html =~ "Tunggu sebentar"
    refute html =~ "Scan QRIS untuk Apresiasi"
    assert has_element?(view, "#donation-form")
  end

  test "keeps the IP reservation after Mayar fails", %{conn: conn} do
    conn = put_peer_data(conn, %{address: {203, 0, 113, 28}, port: 44_328, ssl_cert: nil})

    Req.Test.expect(__MODULE__, fn conn ->
      Plug.Conn.send_resp(conn, 401, "unauthorized")
    end)

    capture_log(fn ->
      {:ok, first_view, _html} = live(conn, ~p"/")
      assert render_submit(first_view, "submit_feedback", tip_params()) =~ "QR belum bisa dibuat"

      {:ok, second_view, _html} = live(conn, ~p"/")
      html = render_submit(second_view, "submit_feedback", tip_params())

      assert html =~ "Tunggu sebentar ya, coba lagi dalam beberapa detik."
      refute html =~ "Scan QRIS untuk Apresiasi"
      assert has_element?(second_view, "#donation-form")
    end)
  end

  test "keeps the IP reservation and donor fail-closed state after persistence fails", %{
    conn: conn
  } do
    conn = put_peer_data(conn, %{address: {203, 0, 113, 29}, port: 44_329, ssl_cert: nil})
    mayar_transaction_id = String.duplicate("x", 200)

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "statusCode" => 200,
        "messages" => "Success",
        "data" => %{
          "transactionId" => mayar_transaction_id,
          "amount" => 10_000,
          "url" => "https://example.invalid/qr/persist-failed-rate-limit"
        }
      })
    end)

    capture_log(fn ->
      {:ok, first_view, _html} = live(conn, ~p"/")
      first_html = render_submit(first_view, "submit_feedback", tip_params())

      assert first_html =~ "Tip belum bisa disimpan"
      refute first_html =~ "Scan QRIS untuk Apresiasi"
      assert has_element?(first_view, "#donation-form")

      {:ok, second_view, _html} = live(conn, ~p"/")
      second_html = render_submit(second_view, "submit_feedback", tip_params())

      assert second_html =~ "Tunggu sebentar ya, coba lagi dalam beberapa detik."
      refute second_html =~ "Scan QRIS untuk Apresiasi"
      assert has_element?(second_view, "#donation-form")
    end)

    assert Repo.get_by(Donation, mayar_transaction_id: mayar_transaction_id) == nil
  end

  defp tip_params do
    %{
      "donation_form" => %{
        "donor_name" => "Rate Limited Tip",
        "reaction" => "good",
        "message" => "",
        "show_appreciation" => "true",
        "amount_option" => "10000"
      }
    }
  end

  defp verify_req_expectations!(_context) do
    Req.Test.verify_on_exit!()
  end

  defp restore_env(key, nil), do: Application.delete_env(:notable, key)
  defp restore_env(key, value), do: Application.put_env(:notable, key, value)
end
