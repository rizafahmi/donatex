defmodule DonatexWeb.QuestionLiveTest do
  use DonatexWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  import Ecto.Query

  alias Donatex.Questions
  alias Donatex.Questions.Question
  alias Donatex.Repo
  alias Donatex.SubmissionLimiter

  setup do
    SubmissionLimiter.reset()
    :ok
  end

  defp set_inserted_at(question, utc_datetime) do
    {1, _} =
      Repo.update_all(
        from(q in Question, where: q.id == ^question.id),
        set: [inserted_at: utc_datetime, updated_at: utc_datetime]
      )

    Repo.get!(Question, question.id)
  end

  defp utc(date, {h, m, s}) do
    DateTime.new!(date, Time.new!(h, m, s), "Etc/UTC")
  end

  # Seconds after WIB midnight for a calendar date (calendar-stable vs wall clock).
  defp seconds_into_wib_date(%Date{} = date, seconds) when is_integer(seconds) do
    {start_utc, _} = Questions.wib_date_range(date)
    DateTime.add(start_utc, seconds, :second)
  end

  describe "route, navigation, and metadata" do
    test "GET /questions renders the board", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/questions")
      assert html =~ "Tanya Jawab"
      assert html =~ "question-form"
    end

    test "question textarea is the primary form focus", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/questions")

      body_index = :binary.match(html, ~s(id="question_form_body")) |> elem(0)
      name_index = :binary.match(html, ~s(id="question_form_name")) |> elem(0)

      assert body_index < name_index
      assert html =~ ~s(id="question_form_body")
      assert html =~ "autofocus"
    end

    test "question form can be collapsed and expanded", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/questions")

      assert html =~ ~s(id="question-form")
      assert html =~ ~s(aria-expanded="true")

      collapsed = render_click(view, "toggle_form", %{})
      refute collapsed =~ ~s(id="question-form")
      assert collapsed =~ ~s(aria-expanded="false")
      assert collapsed =~ "Tulis pertanyaan untuk Riza"

      expanded = render_click(view, "toggle_form", %{})
      assert expanded =~ ~s(id="question-form")
      assert expanded =~ ~s(aria-expanded="true")
    end

    test "header links to Q&A, Feedback, and Admin", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/questions")
      # The donor page hides the header, so verify the shared nav on /questions.
      assert html =~ "Q&amp;A"
      assert html =~ ~p"/admin"
      assert html =~ "Feedback"
    end

    test "discloses that a supplied name is public", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/questions")
      assert html =~ "akan tampil untuk umum"
      assert html =~ "Anonim"
    end

    test "renders a 500-character counter", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/questions")
      assert html =~ "body-counter"
      assert html =~ "/ 500"
    end

    test "marks the route noindex, follow", %{conn: conn} do
      conn = conn |> get(~p"/questions")
      assert conn.assigns[:meta_robots] == "noindex, follow"
      assert conn.assigns[:canonical_url] =~ "/questions"
    end
  end

  describe "submission" do
    test "success toast carries the FlashAutoHide hook so it dismisses on its own", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/questions")

      html =
        render_submit(view, "submit", %{
          "question_form" => %{"name" => "Riza", "body" => "Apa rencana stream besok?"}
        })

      assert html =~ "Pertanyaan terkirim"
      assert html =~ ~s(id="flash-info")
      assert html =~ ~s(phx-hook="FlashAutoHide")
      assert html =~ ~s(data-flash-key="info")
      assert html =~ ~r/data-flash-generation="\d+"/
    end

    test "connection-error toasts do not auto-hide", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/questions")

      assert html =~ ~s(id="client-error")
      assert html =~ ~s(id="server-error")
      # On initial render no flash is set, so the only visible flash
      # elements are the connection-error toasts — none should carry
      # the auto-hide hook (they are managed by phx-connected/disconnected).
      refute html =~ ~s(phx-hook="FlashAutoHide")
    end

    test "immediately publishes a question to Today", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/questions")

      html =
        render_submit(view, "submit", %{
          "question_form" => %{"name" => "Riza", "body" => "Apa rencana stream besok?"}
        })

      assert html =~ "Pertanyaan terkirim"
      assert html =~ "Apa rencana stream besok?"
      assert html =~ "Riza"
      refute html =~ ~s(id="question-form")
      assert html =~ ~s(aria-expanded="false")
      assert [question] = Repo.all(Question)
      assert question.status == "open"
    end

    test "blank name renders as Anonim, not persisted as Anonim", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/questions")

      html =
        render_submit(view, "submit", %{
          "question_form" => %{"name" => "", "body" => "Pertanyaan anonim"}
        })

      assert html =~ "Anonim"
      assert [question] = Repo.all(Question)
      assert question.name == nil
    end

    test "501-character body is rejected and the form value is preserved", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/questions")

      over = String.duplicate("x", 501)

      html =
        render_submit(view, "submit", %{
          "question_form" => %{"name" => "", "body" => over}
        })

      refute html =~ "Pertanyaan terkirim"
      assert html =~ over
      assert [] == Repo.all(Question)
    end

    test "cooldown blocks a second submission within 10 seconds and preserves the form", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/questions")

      render_submit(view, "submit", %{
        "question_form" => %{"name" => "Riza", "body" => "pertanyaan pertama"}
      })

      html =
        render_submit(view, "submit", %{
          "question_form" => %{"name" => "Riza", "body" => "pertanyaan kedua"}
        })

      assert html =~ "Tunggu sebentar"
      assert html =~ "pertanyaan kedua"
      assert length(Repo.all(Question)) == 1
    end

    test "question cooldown is isolated from the feedback cooldown", %{conn: conn} do
      ip = {203, 0, 113, 42}
      assert :ok = SubmissionLimiter.reserve({:feedback, ip})

      {:ok, view, _html} = live(conn, ~p"/questions")

      html =
        render_submit(view, "submit", %{
          "question_form" => %{"name" => "Riza", "body" => "pertanyaan setelah feedback"}
        })

      assert html =~ "Pertanyaan terkirim"
    end

    test "missing visitor session fails safely without inventing an identity", %{conn: conn} do
      {:ok, view, html} = live_isolated(conn, DonatexWeb.QuestionLive, session: %{})

      assert html =~ "Tanya Jawab"

      html =
        render_submit(view, "submit", %{
          "question_form" => %{"name" => "Riza", "body" => "x"}
        })

      refute html =~ "Pertanyaan terkirim"
      assert [] == Repo.all(Question)
    end
  end

  describe "voting" do
    test "toggling a vote updates the count", %{conn: conn} do
      q = Questions.create_question!(%{"body" => "vote me"})

      {:ok, view, _html} = live(conn, ~p"/questions")

      _html = render_click(view, "toggle_vote", %{"id" => q.id})

      [updated] =
        Questions.list_questions_for_date(Questions.wib_date_of_utc_datetime(q.inserted_at))

      assert updated.vote_count == 1
    end

    test "answered questions render a disabled vote button", %{conn: conn} do
      q = Questions.create_question!(%{"body" => "answered q"})
      {:ok, _} = Questions.mark_answered(q.id)

      {:ok, view, _html} = live(conn, ~p"/questions")
      assert has_element?(view, "#question-#{q.id} button[disabled]")
    end

    test "repeated identical flash gets a fresh auto-hide generation", %{conn: conn} do
      q = Questions.create_question!(%{"body" => "answered q"})
      {:ok, _} = Questions.mark_answered(q.id)
      {:ok, view, _html} = live(conn, ~p"/questions")

      first_html = render_click(view, "toggle_vote", %{"id" => q.id})
      second_html = render_click(view, "toggle_vote", %{"id" => q.id})

      [first_generation] =
        Regex.run(~r/data-flash-generation="(\d+)"/, first_html, capture: :all_but_first)

      [second_generation] =
        Regex.run(~r/data-flash-generation="(\d+)"/, second_html, capture: :all_but_first)

      refute first_generation == second_generation
    end
  end

  describe "ranking and tie-breaking" do
    test "open before answered, then votes desc, then oldest first", %{conn: conn} do
      today = Questions.today_wib()

      q1 =
        Questions.create_question!(%{"body" => "a"})
        |> set_inserted_at(seconds_into_wib_date(today, 0))

      q2 =
        Questions.create_question!(%{"body" => "b"})
        |> set_inserted_at(seconds_into_wib_date(today, 1))

      q3 =
        Questions.create_question!(%{"body" => "c"})
        |> set_inserted_at(seconds_into_wib_date(today, 2))

      {:ok, _} = Questions.toggle_vote(q2.id, "v1")
      {:ok, _} = Questions.toggle_vote(q2.id, "v2")
      {:ok, _} = Questions.toggle_vote(q1.id, "v1")
      # Answer q3 only after it has accumulated votes, so voting stays open during voting.
      {:ok, _} = Questions.toggle_vote(q3.id, "v1")
      {:ok, _} = Questions.toggle_vote(q3.id, "v2")
      {:ok, _} = Questions.toggle_vote(q3.id, "v3")
      {:ok, _} = Questions.mark_answered(q3.id)

      {:ok, _view, html} = live(conn, ~p"/questions")

      assert parse_today_order(html) == [q2.id, q1.id, q3.id]
    end
  end

  describe "historical lazy loading and hidden removal" do
    test "previous dates are collapsed and load on expand", %{conn: conn} do
      yesterday = Date.add(Questions.today_wib(), -1)

      q_yesterday =
        Questions.create_question!(%{"body" => "lama"})
        |> set_inserted_at(seconds_into_wib_date(yesterday, 10 * 3600))

      {:ok, view, html} = live(conn, ~p"/questions")

      assert html =~ "date-group-#{Date.to_iso8601(yesterday)}"
      refute html =~ "question-#{q_yesterday.id}"

      date_str = Date.to_iso8601(yesterday)
      _html = render_click(view, "toggle_date", %{"date" => date_str})
      assert has_element?(view, "#question-#{q_yesterday.id}")
      assert has_element?(view, "button[aria-expanded='true']")

      _html = render_click(view, "toggle_date", %{"date" => date_str})
      refute has_element?(view, "#question-#{q_yesterday.id}")
    end

    test "hidden questions are absent from the public DOM", %{conn: conn} do
      q = Questions.create_question!(%{"body" => "visible"})
      hidden = Questions.create_question!(%{"body" => "secret"})
      {:ok, _} = Questions.hide(hidden.id)

      {:ok, view, _html} = live(conn, ~p"/questions")
      assert has_element?(view, "#question-#{q.id}")
      refute has_element?(view, "#question-#{hidden.id}")
    end
  end

  describe "realtime updates" do
    test "a committed vote reorders the board in a connected browser", %{conn: conn} do
      today = Questions.today_wib()

      q1 =
        Questions.create_question!(%{"body" => "a"})
        |> set_inserted_at(seconds_into_wib_date(today, 0))

      q2 =
        Questions.create_question!(%{"body" => "b"})
        |> set_inserted_at(seconds_into_wib_date(today, 1))

      {:ok, view, html} = live(conn, ~p"/questions")
      # Initially ordered by age: q1 (created first) before q2.
      assert hd(parse_today_order(html)) == q1.id

      # A committed vote from "another browser" broadcasts and reorders view_a.
      {:ok, _} = Questions.toggle_vote(q2.id, "v-other-1")
      {:ok, _} = Questions.toggle_vote(q2.id, "v-other-2")

      html_a = render(view)
      assert hd(parse_today_order(html_a)) == q2.id
    end
  end

  describe "midnight rollover" do
    test "rolls today into a collapsed historical group at the WIB boundary", %{conn: conn} do
      # Freeze on a known WIB day, then create the question inside that day before mount
      # so wall-clock "now" cannot land it on a different WIB date.
      day = ~D[2026-07-25]
      before_midnight = utc(~D[2026-07-25], {16, 59, 0})
      after_midnight = utc(~D[2026-07-25], {17, 1, 0})

      q_today =
        Questions.create_question!(%{"body" => "hari ini"})
        |> set_inserted_at(before_midnight)

      {:ok, view, _html} =
        live_isolated(conn, DonatexWeb.QuestionLive, session: %{"current_now" => before_midnight})

      assert has_element?(view, "#today-board")
      assert has_element?(view, "#question-#{q_today.id}")

      # Advance the clock past the WIB midnight (17:00 UTC == 00:00 WIB next day).
      send(view.pid, {:set_current_now, after_midnight})
      send(view.pid, :midnight_rollover)

      html = render(view)

      # Today is now the next WIB date; the prior day's question is only in history.
      refute html =~ "question-#{q_today.id}"
      assert html =~ "date-group-#{Date.to_iso8601(day)}"
    end
  end

  defp parse_today_order(html) do
    ~r{id="today-list"(.*?)</ul>}s
    |> Regex.run(html)
    |> case do
      [_full, section] ->
        Regex.scan(~r{id="question-([0-9a-f-]+)"}, section)
        |> Enum.map(fn [_, id] -> id end)

      nil ->
        []
    end
  end
end
