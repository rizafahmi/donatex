defmodule DonatexWeb.DonateLiveFeedbackCooldownTest do
  use DonatexWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Plug.Test, only: [put_peer_data: 2]

  alias Donatex.FeedbackRateLimiter

  setup do
    FeedbackRateLimiter.reset()
    :ok
  end

  test "blocks a second free feedback from the same IP within 10 seconds without clearing fields",
       %{conn: conn} do
    conn =
      put_peer_data(conn, %{address: {203, 0, 113, 10}, port: 44_321, ssl_cert: nil})

    {:ok, view, _html} = live(conn, ~p"/")

    html =
      render_submit(view, "submit_feedback", %{
        "donation_form" => %{
          "donor_name" => "Riza",
          "reaction" => "great",
          "message" => "Keep going"
        }
      })

    assert html =~ "Terima kasih"

    render_click(view, "new_donation", %{})

    html =
      render_submit(view, "submit_feedback", %{
        "donation_form" => %{
          "donor_name" => "Riza",
          "reaction" => "good",
          "message" => "Second try"
        }
      })

    assert html =~ "Tunggu sebentar"
    refute has_element?(view, "#feedback-thanks")
    assert has_element?(view, "#donation-form")
    assert has_element?(view, "#donation_form_reaction_good:checked")
    assert html =~ "Second try"
  end
end
