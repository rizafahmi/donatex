defmodule DonatexWeb.DonateLiveTest do
  use DonatexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the donor form with preset amounts and optional message", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#donor-page")
    assert has_element?(view, "#donation-form")
    assert has_element?(view, "#donation-form", "Nama kamu")
    assert has_element?(view, "#donation-form", "Rp 5.000")
    assert has_element?(view, "#donation-form", "Rp 10.000")
    assert has_element?(view, "#donation-form", "Rp 25.000")
    assert has_element?(view, "#donation-form", "Pesan (opsional)")

    refute has_element?(view, "#donation_form_custom_amount")
  end

  test "requires a donor name before continuing", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    html =
      view
      |> form("#donation-form",
        donation_form: %{
          "donor_name" => "",
          "amount_option" => "10000",
          "message" => ""
        }
      )
      |> render_submit()

    assert html =~ "Tulis namamu dulu"
  end

  test "requires choosing a preset or custom amount", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    html =
      render_submit(view, "submit", %{
        "donation_form" => %{
          "donor_name" => "Riza",
          "message" => ""
        }
      })

    assert html =~ "Pilih nominal donasi"
  end

  test "shows the custom amount field and validates it", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    html =
      render_change(view, "validate", %{
        "donation_form" => %{
          "donor_name" => "Riza",
          "amount_option" => "custom",
          "message" => "Semangat streamnya"
        }
      })

    assert has_element?(view, "#donation_form_custom_amount")
    assert html =~ ~s(min="1000")
    assert html =~ ~s(step="1000")

    html =
      render_submit(view, "submit", %{
        "donation_form" => %{
          "donor_name" => "Riza",
          "amount_option" => "custom",
          "custom_amount" => "",
          "message" => "Semangat streamnya"
        }
      })

    assert html =~ "Masukkan nominal donasi"
  end

  test "accepts a valid custom amount", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    html =
      render_submit(view, "submit", %{
        "donation_form" => %{
          "donor_name" => "Riza",
          "amount_option" => "custom",
          "custom_amount" => "150000",
          "message" => ""
        }
      })

    assert html =~ "QR belum bisa dibuat sekarang"
    refute html =~ "Masukkan nominal donasi"
    refute html =~ "Harus kelipatan 1000"
  end
end
