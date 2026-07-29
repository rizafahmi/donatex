defmodule NotableWeb.AdminQuestionLiveTest do
  use NotableWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  import Ecto.Query

  alias Notable.Config
  alias Notable.Questions
  alias Notable.Questions.Question
  alias Notable.Repo

  setup do
    basic_auth =
      "Basic " <> Base.encode64("#{Config.admin_username()}:#{Config.admin_password()}")

    conn = Plug.Conn.put_req_header(build_conn(), "authorization", basic_auth)
    {:ok, conn: conn}
  end

  defp set_inserted_at(question, utc_datetime) do
    {1, _} =
      Repo.update_all(
        from(q in Question, where: q.id == ^question.id),
        set: [inserted_at: utc_datetime, updated_at: utc_datetime]
      )

    Repo.get!(Question, question.id)
  end

  test "unauthenticated request is rejected", %{conn: conn} do
    conn = conn |> Plug.Conn.delete_req_header("authorization") |> get(~p"/admin/questions")
    assert conn.status == 401
  end

  test "renders the moderation page and lists questions after expanding a date", %{conn: conn} do
    q = Questions.create_question!(%{"body" => "halo admin"})

    {:ok, view, html} = live(conn, ~p"/admin/questions")
    assert html =~ "Moderasi Pertanyaan"
    refute has_element?(view, "#admin-question-#{q.id}")

    date = Questions.wib_date_of_utc_datetime(q.inserted_at)
    _html = render_click(view, "toggle_date", %{"date" => Date.to_iso8601(date)})
    assert has_element?(view, "#admin-question-#{q.id}")
  end

  test "mark answered and reopen toggle status", %{conn: conn} do
    q = Questions.create_question!(%{"body" => "to answer"})

    {:ok, view, _html} = live(conn, ~p"/admin/questions")
    date = Questions.wib_date_of_utc_datetime(q.inserted_at)
    render_click(view, "toggle_date", %{"date" => Date.to_iso8601(date)})

    assert has_element?(view, "#admin-question-#{q.id} button[phx-click='mark_answered']")
    render_click(view, "mark_answered", %{"id" => q.id})
    assert Repo.get!(Question, q.id).status == "answered"
    assert has_element?(view, "#admin-question-#{q.id} button[phx-click='reopen']")

    render_click(view, "reopen", %{"id" => q.id})
    assert Repo.get!(Question, q.id).status == "open"
  end

  test "hide and restore are orthogonal to answered status", %{conn: conn} do
    q = Questions.create_question!(%{"body" => "to hide"})
    {:ok, _} = Questions.mark_answered(q.id)

    {:ok, view, _html} = live(conn, ~p"/admin/questions")
    date = Questions.wib_date_of_utc_datetime(q.inserted_at)
    render_click(view, "toggle_date", %{"date" => Date.to_iso8601(date)})

    render_click(view, "hide", %{"id" => q.id})
    hidden = Repo.get!(Question, q.id)
    assert hidden.hidden_at != nil
    assert hidden.status == "answered"
    assert has_element?(view, "#admin-question-#{q.id} button[phx-click='restore']")

    render_click(view, "restore", %{"id" => q.id})
    restored = Repo.get!(Question, q.id)
    assert restored.hidden_at == nil
    assert restored.status == "answered"
  end

  test "hidden questions are included in the admin view", %{conn: conn} do
    visible = Questions.create_question!(%{"body" => "v"})
    hidden = Questions.create_question!(%{"body" => "h"})
    {:ok, _} = Questions.hide(hidden.id)

    {:ok, view, _html} = live(conn, ~p"/admin/questions")
    date = Questions.wib_date_of_utc_datetime(visible.inserted_at)
    render_click(view, "toggle_date", %{"date" => Date.to_iso8601(date)})

    assert has_element?(view, "#admin-question-#{visible.id}")
    assert has_element?(view, "#admin-question-#{hidden.id}")
  end

  test "invalid id flashes an error without crashing", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/questions")
    missing = Ecto.UUID.generate()

    render_click(view, "mark_answered", %{"id" => missing})
    assert has_element?(view, "#flash-group")
    # Reopen/hide/restore also safe.
    render_click(view, "reopen", %{"id" => missing})
    render_click(view, "hide", %{"id" => missing})
    render_click(view, "restore", %{"id" => missing})
  end

  test "admin metadata is noindex, nofollow", %{conn: conn} do
    conn = conn |> get(~p"/admin/questions")
    assert conn.assigns[:meta_robots] == "noindex, nofollow"
    assert conn.assigns[:canonical_url] =~ "/admin/questions"
  end

  test "live insert from another source appears after broadcast", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/questions")

    q = Questions.create_question!(%{"body" => "late arrival"})
    _ = render(view)

    date = Questions.wib_date_of_utc_datetime(q.inserted_at)
    render_click(view, "toggle_date", %{"date" => Date.to_iso8601(date)})
    assert has_element?(view, "#admin-question-#{q.id}")
  end

  test "cross-page broadcast: a vote from the public page reaches admin", %{conn: conn} do
    yesterday = Date.add(Questions.today_wib(), -1)
    {start_utc, _} = Questions.wib_date_range(yesterday)

    q =
      Questions.create_question!(%{"body" => "vote me"})
      |> set_inserted_at(DateTime.add(start_utc, 3600, :second))

    # Public viewer (no auth) votes.
    public_conn = build_conn()
    {:ok, pub_view, _html} = live(public_conn, ~p"/questions")
    render_click(pub_view, "toggle_vote", %{"id" => q.id})

    # Admin view sees the updated count after broadcast.
    {:ok, admin_view, _html} = live(conn, ~p"/admin/questions")
    date = Questions.wib_date_of_utc_datetime(q.inserted_at)
    render_click(admin_view, "toggle_date", %{"date" => Date.to_iso8601(date)})

    html = render(admin_view)
    assert html =~ "1 upvote"
  end
end
