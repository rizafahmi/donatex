defmodule DonatexWeb.DonateLiveTipHardeningTest do
  use DonatexWeb.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest

  alias Donatex.Donations.Donation
  alias Donatex.Repo
  alias Donatex.SubmissionLimiter

  setup :verify_req_expectations!

  setup do
    SubmissionLimiter.reset()

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

  test "second tip submit after Mayar failure does not create another QR attempt", %{conn: conn} do
    Req.Test.expect(__MODULE__, fn conn ->
      Plug.Conn.send_resp(conn, 401, "unauthorized")
    end)

    {:ok, view, _html} = live(conn, ~p"/")

    tip_params = %{
      "donation_form" => %{
        "donor_name" => "Double Tip",
        "reaction" => "good",
        "message" => "",
        "show_appreciation" => "true",
        "amount_option" => "10000"
      }
    }

    before_count = Repo.aggregate(Donation, :count)

    capture_log(fn ->
      html = render_submit(view, "submit_feedback", tip_params)
      assert html =~ "QR belum bisa dibuat sekarang"

      html = render_submit(view, "submit_feedback", tip_params)
      assert html =~ "QR belum bisa dibuat sekarang"
      assert has_element?(view, "#donation-form")
      refute html =~ "Scan QRIS untuk Apresiasi"
    end)

    assert Repo.aggregate(Donation, :count) == before_count
  end

  test "successful tip ignores a second tip submit on payment step", %{conn: conn} do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "statusCode" => 200,
        "messages" => "Success",
        "data" => %{
          "transactionId" => "tx-tip-once",
          "amount" => 10_000,
          "url" => "https://example.invalid/qr/tip-once"
        }
      })
    end)

    {:ok, view, _html} = live(conn, ~p"/")

    tip_params = %{
      "donation_form" => %{
        "donor_name" => "Once Tip",
        "reaction" => "good",
        "message" => "",
        "show_appreciation" => "true",
        "amount_option" => "10000"
      }
    }

    html = render_submit(view, "submit_feedback", tip_params)
    assert html =~ "Scan QRIS untuk Apresiasi"

    assert html =~
             "Buka aplikasi ewallet atau ebanking kesayangan kamu untuk scan QRIS"

    refute has_element?(view, "#donation-form")

    before_count = Repo.aggregate(Donation, :count)

    html = render_submit(view, "submit_feedback", tip_params)
    assert html =~ "Scan QRIS untuk Apresiasi"
    assert Repo.aggregate(Donation, :count) == before_count
    assert Repo.get_by!(Donation, mayar_transaction_id: "tx-tip-once").status == "pending"
  end

  test "free submit_feedback is a no-op when step is not form", %{conn: conn} do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "statusCode" => 200,
        "messages" => "Success",
        "data" => %{
          "transactionId" => "tx-free-noop",
          "amount" => 10_000,
          "url" => "https://example.invalid/qr/free-noop"
        }
      })
    end)

    {:ok, view, _html} = live(conn, ~p"/")

    html =
      render_submit(view, "submit_feedback", %{
        "donation_form" => %{
          "donor_name" => "Payment Step",
          "reaction" => "good",
          "message" => "",
          "show_appreciation" => "true",
          "amount_option" => "10000"
        }
      })

    assert html =~ "Scan QRIS untuk Apresiasi"
    before_count = Repo.aggregate(Donation, :count)

    html =
      render_submit(view, "submit_feedback", %{
        "donation_form" => %{
          "donor_name" => "Sneaky Free",
          "reaction" => "great",
          "message" => "should not send"
        }
      })

    assert html =~ "Scan QRIS untuk Apresiasi"
    refute has_element?(view, "#feedback-thanks")
    assert Repo.aggregate(Donation, :count) == before_count
    assert Repo.get_by(Donation, donor_name: "Sneaky Free") == nil
  end

  test "preserves custom tip amount when tip params omit amount fields", %{conn: conn} do
    Req.Test.expect(__MODULE__, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"amount" => 25_000}

      Req.Test.json(conn, %{
        "statusCode" => 200,
        "messages" => "Success",
        "data" => %{
          "transactionId" => "tx-preserve-custom",
          "amount" => 25_000,
          "url" => "https://example.invalid/qr/preserve-custom"
        }
      })
    end)

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#donation-form", donation_form: %{"show_appreciation" => "true"})
    |> render_change()

    view
    |> form("#donation-form",
      donation_form: %{
        "donor_name" => "Preserve Custom",
        "reaction" => "good",
        "show_appreciation" => "true",
        "amount_option" => "25000",
        "message" => ""
      }
    )
    |> render_change()

    html =
      render_submit(view, "submit_feedback", %{
        "donation_form" => %{
          "donor_name" => "Preserve Custom",
          "reaction" => "good",
          "message" => "",
          "show_appreciation" => "true"
        }
      })

    assert html =~ "Scan QRIS untuk Apresiasi"
    donation = Repo.get_by!(Donation, mayar_transaction_id: "tx-preserve-custom")
    assert donation.amount == 25_000
  end

  defmodule PersistFailingDonations do
    @moduledoc false

    def create_pending_donation(attrs) do
      changeset =
        %Donation{}
        |> Donation.changeset(attrs)
        |> Ecto.Changeset.add_error(:donor_name, "nama tip tidak bisa digunakan")
        |> Map.put(:action, :insert)

      {:error, changeset}
    end
  end

  test "tip persist changeset errors re-render on form inputs", %{conn: conn} do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "statusCode" => 200,
        "messages" => "Success",
        "data" => %{
          "transactionId" => "tx-tip-persist-fail",
          "amount" => 10_000,
          "url" => "https://example.invalid/qr/tip-persist-fail"
        }
      })
    end)

    original = Application.get_env(:donatex, :donations)

    on_exit(fn ->
      restore_env(:donations, original)
    end)

    Application.put_env(:donatex, :donations, PersistFailingDonations)

    {:ok, view, _html} = live(conn, ~p"/")

    tip_params = %{
      "donation_form" => %{
        "donor_name" => "Tip Persist Fail",
        "reaction" => "good",
        "message" => "keep me",
        "show_appreciation" => "true",
        "amount_option" => "10000"
      }
    }

    capture_log(fn ->
      html = render_submit(view, "submit_feedback", tip_params)

      assert html =~ "Tip belum bisa disimpan"
      assert html =~ "nama tip tidak bisa digunakan"
      assert html =~ ~s(value="Tip Persist Fail")
      assert has_element?(view, "#donation-form")
      assert has_element?(view, "#amount-options")
      refute html =~ "Scan QRIS untuk Apresiasi"
    end)

    assert Repo.get_by(Donation, donor_name: "Tip Persist Fail") == nil
  end

  defp verify_req_expectations!(_context) do
    Req.Test.verify_on_exit!()
  end

  defp restore_env(key, nil), do: Application.delete_env(:donatex, key)
  defp restore_env(key, value), do: Application.put_env(:donatex, key, value)
end
