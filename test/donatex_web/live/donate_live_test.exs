defmodule DonatexWeb.DonateLiveTest do
  use DonatexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the donor form with preset amounts and optional message", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/donate")

    assert html =~ "Donate"
    assert html =~ "Your name"
    assert html =~ "Rp 5.000"
    assert html =~ "Rp 10.000"
    assert html =~ "Rp 25.000"
    assert html =~ "Message (optional)"

    refute has_element?(view, "#donation_form_custom_amount")
  end

  test "requires a donor name before continuing", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/donate")

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

    assert html =~ "Please enter your name"
  end

  test "requires choosing a preset or custom amount", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/donate")

    html =
      render_submit(view, "submit", %{
        "donation_form" => %{
          "donor_name" => "Riza",
          "message" => ""
        }
      })

    assert html =~ "Choose a donation amount"
  end

  test "shows the custom amount field and validates it", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/donate")

    render_change(view, "validate", %{
      "donation_form" => %{
        "donor_name" => "Riza",
        "amount_option" => "custom",
        "message" => "Semangat streamnya"
      }
    })

    assert has_element?(view, "#donation_form_custom_amount")

    html =
      render_submit(view, "submit", %{
        "donation_form" => %{
          "donor_name" => "Riza",
          "amount_option" => "custom",
          "custom_amount" => "",
          "message" => "Semangat streamnya"
        }
      })

    assert html =~ "Enter your donation amount"
  end
end
