defmodule DonatexWeb.DonateLiveFeedbackCooldownTest do
  use DonatexWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Plug.Test, only: [put_peer_data: 2]

  alias Donatex.SubmissionLimiter

  setup do
    SubmissionLimiter.reset()
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

  test "failed persist releases cooldown so a retry can succeed", %{conn: conn} do
    ip = {203, 0, 113, 11}
    conn = put_peer_data(conn, %{address: ip, port: 44_322, ssl_cert: nil})

    assert :ok = SubmissionLimiter.reserve({:feedback, ip})
    # Simulate the DonateLive failure path: reserve charged, persist failed, release.
    assert :ok = SubmissionLimiter.release({:feedback, ip})

    {:ok, view, _html} = live(conn, ~p"/")

    html =
      render_submit(view, "submit_feedback", %{
        "donation_form" => %{
          "donor_name" => "Retry After Fail",
          "reaction" => "good",
          "message" => "should work"
        }
      })

    assert html =~ "Terima kasih"
    assert has_element?(view, "#feedback-thanks")
  end
end
