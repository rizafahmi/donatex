defmodule DonatexWeb.QuestionsJourneyTest do
  use DonatexWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Donatex.Config
  alias Donatex.Questions
  alias Donatex.Questions.QuestionVote
  alias Donatex.Repo

  import Ecto.Query

  setup do
    basic_auth =
      "Basic " <> Base.encode64("#{Config.admin_username()}:#{Config.admin_password()}")

    admin_conn = Plug.Conn.put_req_header(build_conn(), "authorization", basic_auth)
    {:ok, admin_conn: admin_conn, public_conn: build_conn()}
  end

  # Trigger the VisitorId plug on the connection and read the raw visitor id
  # back from the session. Two `live` calls on the returned conn share the same
  # visitor id; two `build_conn`s do not.
  defp prime_visitor(public_conn) do
    conn = get(public_conn, ~p"/questions")
    {conn, Plug.Conn.get_session(conn, "visitor_id")}
  end

  describe "end-to-end audience and streamer journey" do
    test "submit, cross-browser upvote, answer, reopen, hide, restore converge live", %{
      admin_conn: admin_conn,
      public_conn: public_conn
    } do
      # 1. Anonymous submission on browser A lands on Today immediately.
      {:ok, view_a, _html} = live(public_conn, ~p"/questions")

      html =
        render_submit(view_a, "submit", %{
          "question_form" => %{"name" => "Riza", "body" => "Pertanyaan akhir stream?"}
        })

      assert html =~ "Pertanyaan terkirim"
      assert html =~ "Pertanyaan akhir stream?"
      [question] = Repo.all(Questions.Question)
      assert question.status == "open"

      qid = question.id

      # 2. A second browser session connects and upvotes the question, which
      #    broadcasts back to browser A and updates the vote count.
      {:ok, view_b, _html} = live(public_conn, ~p"/questions")

      _html = render_click(view_b, "toggle_vote", %{"id" => qid})
      assert [vote] = Repo.all(QuestionVote)
      assert vote.question_id == qid

      html_a = render(view_a)

      [count_match] =
        Regex.run(~r/vote-count-#{qid}".*?>\s*(\d+)\s*</s, html_a, capture: :all_but_first)

      assert count_match == "1"

      # 3. The streamer marks it answered; the public board renders a disabled
      #    vote button in real time and shows the answered badge.
      {:ok, admin, _html} = live(admin_conn, ~p"/admin/questions")

      today = Questions.wib_date_of_utc_datetime(question.inserted_at)
      _html = render_click(admin, "toggle_date", %{"date" => Date.to_iso8601(today)})
      _html = render_click(admin, "mark_answered", %{"id" => qid})

      html_a = render(view_a)
      assert has_element?(view_a, "#question-#{qid} button[disabled]")
      assert html_a =~ "Terjawab"

      # 4. Reopen re-enables public voting.
      _html = render_click(admin, "reopen", %{"id" => qid})
      html_a = render(view_a)
      refute has_element?(view_a, "#question-#{qid} button[disabled]")
      refute html_a =~ "Terjawab"

      # 5. Hiding removes the question from the public board (real time), but it
      #    remains visible to admin with a hidden badge.
      _html = render_click(admin, "hide", %{"id" => qid})
      html_a = render(view_a)
      refute html_a =~ "question-#{qid}"
      html_admin = render(admin)
      assert html_admin =~ "question-#{qid}"
      assert html_admin =~ "Tersembunyi"

      # 6. Restore brings it back to the public board, still open and votable.
      _html = render_click(admin, "restore", %{"id" => qid})
      _html_a = render(view_a)
      assert has_element?(view_a, "#question-#{qid}")
      assert has_element?(view_a, "#question-#{qid} button[phx-click='toggle_vote']")
    end
  end

  describe "visitor identity isolation" do
    test "two tabs sharing one visitor session cannot create duplicate votes", %{
      public_conn: public_conn
    } do
      {conn, _raw} = prime_visitor(public_conn)
      q = Questions.create_question!(%{"body" => "shared session"})

      {:ok, view_a, _html} = live(conn, ~p"/questions")
      {:ok, view_b, _html} = live(conn, ~p"/questions")

      # First tab votes -> one row.
      _html = render_click(view_a, "toggle_vote", %{"id" => q.id})
      assert Repo.aggregate(from(v in QuestionVote, where: v.question_id == ^q.id), :count) == 1

      # Second tab shares the visitor id, so its vote toggles the existing vote
      # off instead of inserting a duplicate row.
      _html = render_click(view_b, "toggle_vote", %{"id" => q.id})
      assert Repo.aggregate(from(v in QuestionVote, where: v.question_id == ^q.id), :count) == 0
    end

    test "two distinct visitor sessions vote independently", %{public_conn: public_conn} do
      q = Questions.create_question!(%{"body" => "independent"})

      {:ok, view_a, _html} = live(public_conn, ~p"/questions")
      {:ok, view_b, _html} = live(public_conn, ~p"/questions")

      _ = render_click(view_a, "toggle_vote", %{"id" => q.id})
      _ = render_click(view_b, "toggle_vote", %{"id" => q.id})

      # Two fresh connections get distinct visitor_ids, so both votes land.
      assert Repo.aggregate(from(v in QuestionVote, where: v.question_id == ^q.id), :count) == 2
    end
  end

  describe "no raw visitor identifier leakage" do
    test "only the hash is persisted, never the raw visitor id", %{public_conn: public_conn} do
      {conn, raw_visitor_id} = prime_visitor(public_conn)
      assert is_binary(raw_visitor_id) and raw_visitor_id != ""

      {:ok, view, _html} = live(conn, ~p"/questions")

      _ =
        render_submit(view, "submit", %{
          "question_form" => %{"name" => "", "body" => "leak check"}
        })

      [question] = Repo.all(Questions.Question)
      _ = render_click(view, "toggle_vote", %{"id" => question.id})

      # No vote row stores the raw visitor id as its hash.
      for vote <- Repo.all(QuestionVote) do
        refute vote.visitor_hash == raw_visitor_id
        # SHA-256 of the raw id is a 64-char hex string, distinct from the raw id.
        assert byte_size(vote.visitor_hash) == 64
      end
    end

    test "submit and vote do not log the raw visitor id", %{public_conn: public_conn} do
      {conn, raw_visitor_id} = prime_visitor(public_conn)

      {:ok, view, _html} = live(conn, ~p"/questions")

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          _ =
            render_submit(view, "submit", %{
              "question_form" => %{"name" => "", "body" => "log check"}
            })

          [question] = Repo.all(Questions.Question)
          _ = render_click(view, "toggle_vote", %{"id" => question.id})
        end)

      refute log =~ raw_visitor_id
    end
  end
end
