defmodule Notable.QuestionsTest do
  use Notable.DataCase, async: false

  import Ecto.Query

  alias Notable.Questions
  alias Notable.Questions.Question
  alias Notable.Questions.QuestionVote
  alias Notable.Repo

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

  describe "create_question/1" do
    test "persists a question with default open status and nil name" do
      assert {:ok, %Question{} = q} = Questions.create_question(%{"body" => "Apa rencana?"})
      assert q.status == "open"
      assert q.name == nil
      assert q.body == "Apa rencana?"
      assert q.hidden_at == nil
    end

    test "normalizes a blank name to nil and trims body" do
      assert {:ok, q} = Questions.create_question(%{"name" => "   ", "body" => "  halo  "})
      assert q.name == nil
      assert q.body == "halo"
    end

    test "rejects an empty body" do
      assert {:error, changeset} = Questions.create_question(%{"body" => "  "})
      assert errors_on(changeset)[:body]
    end

    test "broadcasts {:question_created, id} after commit" do
      Phoenix.PubSub.subscribe(Notable.PubSub, "questions")

      assert {:ok, %Question{id: id}} = Questions.create_question(%{"body" => "halo"})
      assert_received {:question_created, ^id}
    end
  end

  describe "toggle_vote/2" do
    setup do
      {:ok, question: insert_question("body")}
    end

    defp insert_question(body) do
      {:ok, q} = Questions.create_question(%{"body" => body})
      q
    end

    test "adds a vote and returns {:ok, :added}", %{question: question} do
      assert {:ok, :added} = Questions.toggle_vote(question.id, "visitor-a")
      assert [_vote] = Repo.all(QuestionVote)
    end

    test "persists only the SHA-256 hash of the visitor id, never the raw value" do
      assert {:ok, :added} = Questions.toggle_vote(question_fixture().id, "visitor-a")
      [vote] = Repo.all(QuestionVote)
      assert byte_size(vote.visitor_hash) == 64

      assert vote.visitor_hash ==
               :crypto.hash(:sha256, "visitor-a") |> Base.encode16(case: :lower)

      refute vote.visitor_hash == "visitor-a"
    end

    test "toggling again removes the vote and returns {:ok, :removed}", %{question: question} do
      assert {:ok, :added} = Questions.toggle_vote(question.id, "visitor-a")
      assert {:ok, :removed} = Questions.toggle_vote(question.id, "visitor-a")
      assert [] == Repo.all(QuestionVote)
    end

    test "different visitors can vote independently", %{question: question} do
      assert {:ok, :added} = Questions.toggle_vote(question.id, "visitor-a")
      assert {:ok, :added} = Questions.toggle_vote(question.id, "visitor-b")
      assert length(Repo.all(QuestionVote)) == 2
    end

    test "a duplicate vote insert is rejected by the unique index", %{question: question} do
      assert {:ok, :added} = Questions.toggle_vote(question.id, "visitor-a")
      hash = :crypto.hash(:sha256, "visitor-a") |> Base.encode16(case: :lower)

      {:error, changeset} =
        %QuestionVote{}
        |> QuestionVote.changeset(%{question_id: question.id, visitor_hash: hash})
        |> Repo.insert()

      assert errors_on(changeset)[:question_id]
      assert length(Repo.all(QuestionVote)) == 1
    end

    test "voting on an answered question is rejected", %{question: question} do
      assert {:ok, _} = Questions.mark_answered(question.id)
      assert {:error, :answered} = Questions.toggle_vote(question.id, "visitor-a")
      assert [] == Repo.all(QuestionVote)
    end

    test "reopening an answered question re-enables voting", %{question: question} do
      assert {:ok, _} = Questions.mark_answered(question.id)
      assert {:ok, _} = Questions.reopen(question.id)
      assert {:ok, :added} = Questions.toggle_vote(question.id, "visitor-a")
    end

    test "voting on a hidden question is rejected", %{question: question} do
      assert {:ok, _} = Questions.hide(question.id)
      assert {:error, :hidden} = Questions.toggle_vote(question.id, "visitor-a")
      assert [] == Repo.all(QuestionVote)
    end

    test "voting on a missing question returns {:error, :not_found}" do
      assert {:error, :not_found} = Questions.toggle_vote(Ecto.UUID.generate(), "visitor-a")
    end

    test "broadcasts {:question_changed, id} after toggling", %{question: question} do
      id = question.id
      Phoenix.PubSub.subscribe(Notable.PubSub, "questions")
      assert {:ok, :added} = Questions.toggle_vote(question.id, "visitor-a")
      assert_received {:question_changed, ^id}
    end
  end

  defp question_fixture(attrs \\ %{}) do
    {:ok, q} = Questions.create_question(Map.merge(%{"body" => "body"}, attrs))
    q
  end

  describe "moderation and status" do
    test "mark_answered and reopen toggle status" do
      q = question_fixture()
      assert {:ok, %{status: "answered"}} = Questions.mark_answered(q.id)
      assert {:ok, %{status: "open"}} = Questions.reopen(q.id)
    end

    test "hide and restore are orthogonal to status" do
      q = question_fixture()
      assert {:ok, %{status: "answered"}} = Questions.mark_answered(q.id)
      assert {:ok, hidden} = Questions.hide(q.id)
      assert hidden.hidden_at != nil
      assert hidden.status == "answered"
      assert {:ok, restored} = Questions.restore(hidden.id)
      assert restored.hidden_at == nil
      assert restored.status == "answered"
    end

    test "mark_answered broadcasts {:question_changed, id}" do
      q = question_fixture()
      id = q.id
      Phoenix.PubSub.subscribe(Notable.PubSub, "questions")
      assert {:ok, _} = Questions.mark_answered(q.id)
      assert_received {:question_changed, ^id}
    end

    test "unknown id returns {:error, :not_found}" do
      missing = Ecto.UUID.generate()
      assert {:error, :not_found} = Questions.mark_answered(missing)
      assert {:error, :not_found} = Questions.reopen(missing)
      assert {:error, :not_found} = Questions.hide(missing)
      assert {:error, :not_found} = Questions.restore(missing)
    end
  end

  describe "WIB date helpers" do
    test "wib_date_of_utc_datetime maps UTC to the Asia/Jakarta date" do
      # 2026-07-24 17:00 UTC == 2026-07-25 00:00 WIB
      assert Questions.wib_date_of_utc_datetime(utc(~D[2026-07-24], {17, 0, 0})) == ~D[2026-07-25]
      # 2026-07-25 16:59 UTC == 2026-07-25 23:59 WIB
      assert Questions.wib_date_of_utc_datetime(utc(~D[2026-07-25], {16, 59, 59})) ==
               ~D[2026-07-25]

      # 2026-07-25 17:00 UTC == 2026-07-26 00:00 WIB
      assert Questions.wib_date_of_utc_datetime(utc(~D[2026-07-25], {17, 0, 0})) == ~D[2026-07-26]
    end

    test "wib_date_range is half-open across the WIB day" do
      {start_utc, end_utc} = Questions.wib_date_range(~D[2026-07-25])
      assert start_utc == utc(~D[2026-07-24], {17, 0, 0})
      assert end_utc == utc(~D[2026-07-25], {17, 0, 0})
    end
  end

  describe "list_questions_for_date/2" do
    test "orders open before answered, then votes desc, then oldest first" do
      q1 = set_inserted_at(question_fixture(%{"body" => "a"}), utc(~D[2026-07-25], {0, 0, 0}))
      q2 = set_inserted_at(question_fixture(%{"body" => "b"}), utc(~D[2026-07-25], {0, 0, 1}))
      q3 = set_inserted_at(question_fixture(%{"body" => "c"}), utc(~D[2026-07-25], {0, 0, 2}))

      # q2 gets two votes, q1 gets one, q3 answered with three votes
      Questions.toggle_vote(q2.id, "v1")
      Questions.toggle_vote(q2.id, "v2")
      Questions.toggle_vote(q1.id, "v1")
      Questions.mark_answered(q3.id)
      Questions.toggle_vote(q3.id, "v1")
      Questions.toggle_vote(q3.id, "v2")
      Questions.toggle_vote(q3.id, "v3")

      ordered = Questions.list_questions_for_date(~D[2026-07-25]) |> Enum.map(& &1.question.id)
      # open first: q2 (2 votes) then q1 (1 vote); then answered q3 (3 votes)
      assert ordered == [q2.id, q1.id, q3.id]
    end

    test "vote_count is aggregated and excluded for hidden questions" do
      q = question_fixture(%{"body" => "visible"})
      hidden = question_fixture(%{"body" => "hidden"})
      Questions.toggle_vote(q.id, "v1")
      Questions.hide(hidden.id)

      rows = Questions.list_questions_for_date(Questions.wib_date_of_utc_datetime(q.inserted_at))
      ids = Enum.map(rows, & &1.question.id)
      assert q.id in ids
      refute hidden.id in ids
      visible = Enum.find(rows, &(&1.question.id == q.id))
      assert visible.vote_count == 1
    end

    test "marks voted? true for the current visitor hash and false otherwise" do
      q = question_fixture(%{"body" => "x"})
      Questions.toggle_vote(q.id, "visitor-a")

      hash = :crypto.hash(:sha256, "visitor-a") |> Base.encode16(case: :lower)
      today = Questions.wib_date_of_utc_datetime(q.inserted_at)

      rows = Questions.list_questions_for_date(today, visitor_hash: hash)
      assert Enum.find(rows, &(&1.question.id == q.id)).voted == true

      other = :crypto.hash(:sha256, "visitor-b") |> Base.encode16(case: :lower)
      rows_other = Questions.list_questions_for_date(today, visitor_hash: other)
      assert Enum.find(rows_other, &(&1.question.id == q.id)).voted == false
    end

    test "admin view includes hidden questions" do
      q = question_fixture(%{"body" => "visible"})
      hidden = question_fixture(%{"body" => "hidden"})
      Questions.hide(hidden.id)

      today = Questions.wib_date_of_utc_datetime(q.inserted_at)
      rows = Questions.list_questions_for_date(today, include_hidden: true)
      ids = Enum.map(rows, & &1.question.id)
      assert q.id in ids
      assert hidden.id in ids
    end

    test "WIB boundary: a question at UTC 17:00 rolls into the next WIB date" do
      before_midnight =
        set_inserted_at(question_fixture(%{"body" => "late"}), utc(~D[2026-07-25], {16, 59, 59}))

      after_midnight =
        set_inserted_at(question_fixture(%{"body" => "next"}), utc(~D[2026-07-25], {17, 0, 0}))

      rows_25 = Questions.list_questions_for_date(~D[2026-07-25])
      rows_26 = Questions.list_questions_for_date(~D[2026-07-26])

      assert before_midnight.id in Enum.map(rows_25, & &1.question.id)
      assert after_midnight.id in Enum.map(rows_26, & &1.question.id)
    end
  end

  describe "list_date_summaries/1" do
    test "returns newest-first date groups with total and open counts, excluding hidden" do
      q_today =
        set_inserted_at(question_fixture(%{"body" => "t"}), utc(~D[2026-07-25], {10, 0, 0}))

      _q_yesterday =
        set_inserted_at(question_fixture(%{"body" => "y"}), utc(~D[2026-07-24], {10, 0, 0}))

      q_hidden =
        set_inserted_at(question_fixture(%{"body" => "h"}), utc(~D[2026-07-25], {11, 0, 0}))

      Questions.mark_answered(q_today.id)
      Questions.hide(q_hidden.id)

      summaries = Questions.list_date_summaries()
      dates = Enum.map(summaries, & &1.wib_date)

      assert ~D[2026-07-25] in dates
      assert ~D[2026-07-24] in dates
      # newest first
      assert Enum.find_index(summaries, &(&1.wib_date == ~D[2026-07-25])) <
               Enum.find_index(summaries, &(&1.wib_date == ~D[2026-07-24]))

      today = Enum.find(summaries, &(&1.wib_date == ~D[2026-07-25]))
      # q_today answered, q_hidden hidden => only q_today counts for total, 0 open
      assert today.total == 1
      assert today.open == 0

      yesterday = Enum.find(summaries, &(&1.wib_date == ~D[2026-07-24]))
      assert yesterday.total == 1
      assert yesterday.open == 1
    end
  end
end
