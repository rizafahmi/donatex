defmodule DonatexWeb.DonateLiveTest do
  use DonatexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Plug.Test, only: [put_peer_data: 2]

  test "renders the donor form with optional message and collapsed appreciation", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#donor-page")
    assert has_element?(view, "#donation-form")
    assert has_element?(view, "#donation-form", "Nama kamu")
    assert has_element?(view, "#donation-form", "Pesan (opsional)")
    assert has_element?(view, "#appreciation-toggle")
    refute has_element?(view, "#amount-options")
    refute has_element?(view, "#donation_form_custom_amount")
  end

  test "brands the public experience as Notable", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ ~s(<title data-default="Notable" data-suffix=" · Notable">)
  end

  test "identifies the Indonesian document language", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ ~s(<html lang="id")
  end

  test "hides amount choices until appreciation is enabled", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#appreciation-toggle")
    refute has_element?(view, "#amount-options")

    view
    |> form("#donation-form", donation_form: %{"show_appreciation" => "true"})
    |> render_change()

    assert has_element?(view, "#amount-options")
    assert has_element?(view, "#amount-options", "Rp 5.000")
    assert has_element?(view, "#amount-options", "Rp 10.000")
    assert has_element?(view, "#amount-options", "Rp 25.000")
  end

  test "shows tip CTA only when appreciation is enabled", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#donation-form", "Kirim feedback")
    refute has_element?(view, "#tip-submit")

    view
    |> form("#donation-form", donation_form: %{"show_appreciation" => "true"})
    |> render_change()

    assert has_element?(view, "#donation-form", "Kirim feedback")
    assert has_element?(view, "#tip-submit")
  end

  test "hides tip UI when appreciation is turned off", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#donation-form", donation_form: %{"show_appreciation" => "true"})
    |> render_change()

    assert has_element?(view, "#amount-options")
    assert has_element?(view, "#tip-submit")

    view
    |> form("#donation-form", donation_form: %{"show_appreciation" => "false"})
    |> render_change()

    refute has_element?(view, "#amount-options")
    refute has_element?(view, "#tip-submit")
    assert has_element?(view, "#donation-form", "Kirim feedback")
  end

  test "presents feedback-first copy on the default donor path", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")

    assert has_element?(view, "#donor-page h1", donor_hero_headline())
    assert html =~ "Tulis pesan atau masukan Anda secara gratis"
    assert has_element?(view, "#donation-form", "Siapkan feedbackmu")
    refute html =~ "Pilih nominal, tulis pesan, lalu bayar via QRIS"
    refute html =~ "Siapkan dukunganmu"
    refute html =~ "QRIS unik untuk setiap donasi"
  end

  test "renders the four approved reaction choices", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#donation_form_reaction_bad[value=bad]")
    assert has_element?(view, "#donation_form_reaction_ok[value=ok]")
    assert has_element?(view, "#donation_form_reaction_good[value=good]")
    assert has_element?(view, "#donation_form_reaction_great[value=great]")
  end

  test "requires a reaction before continuing", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    html =
      view
      |> form("#donation-form",
        donation_form: %{
          "donor_name" => "Riza",
          "message" => ""
        }
      )
      |> render_submit()

    assert html =~ "Pilih satu reaksi"
  end

  test "requires a donor name before continuing", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    html =
      view
      |> form("#donation-form",
        donation_form: %{
          "donor_name" => "",
          "message" => ""
        }
      )
      |> render_submit()

    assert html =~ "Tulis namamu dulu"
  end

  test "limits donor names to 64 characters", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    html =
      view
      |> form("#donation-form",
        donation_form: %{
          "donor_name" => String.duplicate("a", 65),
          "reaction" => "good",
          "message" => ""
        }
      )
      |> render_submit()

    assert html =~ "Maksimal 64 karakter"
  end

  test "limits optional messages to 280 characters", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    html =
      view
      |> form("#donation-form",
        donation_form: %{
          "donor_name" => "Riza",
          "reaction" => "good",
          "message" => String.duplicate("a", 281)
        }
      )
      |> render_submit()

    assert html =~ "Pesan maksimal 280 karakter"
  end

  test "allows browsers to enter the full 280-character message limit", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#donation_form_message[maxlength='280']")
  end

  test "describes a missing appreciation amount choice as a tip", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#donation-form", donation_form: %{"show_appreciation" => "true"})
    |> render_change()

    html =
      render_submit(view, "submit", %{
        "donation_form" => %{
          "donor_name" => "Riza",
          "show_appreciation" => "true",
          "amount_option" => "",
          "message" => ""
        }
      })

    assert html =~ "Pilih nominal tip"
    refute html =~ "Pilih nominal donasi"
  end

  test "describes a missing custom appreciation amount as a tip", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#donation-form", donation_form: %{"show_appreciation" => "true"})
    |> render_change()

    html =
      render_change(view, "validate", %{
        "donation_form" => %{
          "donor_name" => "Riza",
          "reaction" => "good",
          "show_appreciation" => "true",
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
          "reaction" => "good",
          "show_appreciation" => "true",
          "amount_option" => "custom",
          "custom_amount" => "",
          "message" => "Semangat streamnya"
        }
      })

    assert html =~ "Masukkan nominal tip"
    refute html =~ "Masukkan nominal donasi"
  end

  test "accepts a valid custom amount", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    html =
      render_submit(view, "submit", %{
        "donation_form" => %{
          "donor_name" => "Riza",
          "reaction" => "good",
          "show_appreciation" => "true",
          "amount_option" => "custom",
          "custom_amount" => "150000",
          "message" => ""
        }
      })

    assert html =~ "QR belum bisa dibuat sekarang"
    refute html =~ "Masukkan nominal donasi"
    refute html =~ "Harus kelipatan 1000"
  end

  test "submits free feedback and shows a thank-you reset state", %{conn: conn} do
    conn =
      put_peer_data(conn, %{address: {203, 0, 113, 20}, port: 44_322, ssl_cert: nil})

    {:ok, view, _html} = live(conn, ~p"/")

    html =
      render_submit(view, "submit_feedback", %{
        "donation_form" => %{
          "donor_name" => "Riza",
          "reaction" => "great",
          "message" => "Stream-nya seru"
        }
      })

    assert html =~ "Terima kasih"
    assert has_element?(view, "#feedback-thanks")
    assert has_element?(view, "#feedback-thanks[role='status'][aria-live='polite']")

    feedback =
      Donatex.Repo.get_by!(Donatex.Donations.Donation, donor_name: "Riza", status: "sent")

    assert feedback.reaction == "great"
    assert feedback.message == "Stream-nya seru"
    assert is_nil(feedback.amount)
  end

  test "broadcasts accepted free feedback for live admin insert", %{conn: conn} do
    conn =
      put_peer_data(conn, %{address: {203, 0, 113, 21}, port: 44_323, ssl_cert: nil})

    Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:created")

    {:ok, view, _html} = live(conn, ~p"/")

    render_submit(view, "submit_feedback", %{
      "donation_form" => %{
        "donor_name" => "Live Admin",
        "reaction" => "good",
        "message" => "halo admin"
      }
    })

    assert_receive {:donation_created, %Donatex.Donations.Donation{} = feedback}
    assert feedback.donor_name == "Live Admin"
    assert feedback.status == "sent"
    assert is_nil(feedback.amount)
  end

  test "Enter / primary submit without _tip stays free even with appreciation and amount", %{
    conn: conn
  } do
    conn =
      put_peer_data(conn, %{address: {203, 0, 113, 22}, port: 44_324, ssl_cert: nil})

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#donation-form", donation_form: %{"show_appreciation" => "true"})
    |> render_change()

    html =
      view
      |> form("#donation-form",
        donation_form: %{
          "donor_name" => "Riza",
          "reaction" => "good",
          "message" => "Tetap apresiasi, kirim gratis",
          "show_appreciation" => "true",
          "amount_option" => "10000"
        }
      )
      |> render_submit()

    assert html =~ "Terima kasih"
    assert has_element?(view, "#feedback-thanks")
    refute html =~ "Scan QRIS"
    refute has_element?(view, "#payment-expiry")

    feedback =
      Donatex.Repo.get_by!(Donatex.Donations.Donation, donor_name: "Riza", status: "sent")

    assert feedback.message == "Tetap apresiasi, kirim gratis"
    assert feedback.status == "sent"
    assert is_nil(feedback.amount)
  end

  test "ignores tip submit when appreciation is off", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    before_count = Donatex.Repo.aggregate(Donatex.Donations.Donation, :count)

    html =
      render_submit(view, "submit_feedback", %{
        "_tip" => "1",
        "donation_form" => %{
          "donor_name" => "Crafted Tip",
          "reaction" => "good",
          "message" => "",
          "show_appreciation" => "false",
          "amount_option" => "10000"
        }
      })

    assert has_element?(view, "#donation-form")
    refute has_element?(view, "#payment-expiry")
    refute html =~ "Scan QRIS"
    assert Donatex.Repo.aggregate(Donatex.Donations.Donation, :count) == before_count
    assert Donatex.Repo.get_by(Donatex.Donations.Donation, donor_name: "Crafted Tip") == nil
  end

  test "free submit_feedback on thanks step is a no-op", %{conn: conn} do
    conn =
      put_peer_data(conn, %{address: {203, 0, 113, 23}, port: 44_325, ssl_cert: nil})

    {:ok, view, _html} = live(conn, ~p"/")

    render_submit(view, "submit_feedback", %{
      "donation_form" => %{
        "donor_name" => "Thanks Guard",
        "reaction" => "good",
        "message" => "first"
      }
    })

    assert has_element?(view, "#feedback-thanks")
    before_count = Donatex.Repo.aggregate(Donatex.Donations.Donation, :count)

    html =
      render_submit(view, "submit_feedback", %{
        "donation_form" => %{
          "donor_name" => "Thanks Guard 2",
          "reaction" => "great",
          "message" => "second should not send"
        }
      })

    assert html =~ "Terima kasih"
    assert has_element?(view, "#feedback-thanks")
    assert Donatex.Repo.aggregate(Donatex.Donations.Donation, :count) == before_count
    assert Donatex.Repo.get_by(Donatex.Donations.Donation, donor_name: "Thanks Guard 2") == nil
  end
end
