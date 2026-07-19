defmodule DonatexWeb.DonateLivePresenceTest do
  use DonatexWeb.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest

  alias DonatexWeb.DonateLive
  alias DonatexWeb.Presence

  defmodule FailingTrack do
    def track(_pid, _topic, _key, _meta), do: {:error, :tracker_unavailable}
    def list(topic), do: Presence.list(topic)
    def untrack(pid, topic, key), do: Presence.untrack(pid, topic, key)
  end

  defmodule ExitingTrack do
    def track(_pid, _topic, _key, _meta), do: exit(:noproc)
    def list(topic), do: Presence.list(topic)
    def untrack(pid, topic, key), do: Presence.untrack(pid, topic, key)
  end

  defmodule ExitingList do
    def track(pid, topic, key, meta), do: Presence.track(pid, topic, key, meta)
    def list(_topic), do: exit(:noproc)
    def untrack(pid, topic, key), do: Presence.untrack(pid, topic, key)
  end

  setup do
    original = Application.get_env(:donatex, :visitor_presence)

    on_exit(fn ->
      restore_visitor_presence(original)
    end)

    :ok
  end

  test "hides low counts, then updates all visitors at the threshold", %{conn: conn} do
    topic = unique_topic()
    :ok = Phoenix.PubSub.subscribe(Donatex.PubSub, topic)

    first = start_view(conn, topic, "visitor-one")
    assert_join()
    refute_presence_indicator(first)

    second = start_view(conn, topic, "visitor-two")
    assert_join()
    refute_presence_indicator(first)
    refute_presence_indicator(second)

    third = start_view(conn, topic, "visitor-three")
    assert_join()

    for view <- [first, second, third] do
      assert_presence_count(view, 3)
    end

    fourth = start_view(conn, topic, "visitor-four")
    assert_join()

    for view <- [first, second, third, fourth] do
      assert_presence_count(view, 4)
    end

    assert_eventually(fn ->
      has_element?(first, "#visitor-presence-count [aria-hidden='true']")
    end)

    refute has_element?(first, "#visitor-presence-count[role]")
    refute has_element?(first, "#visitor-presence-count[aria-live]")
  end

  test "deduplicates tabs and decrements only after the final tab closes", %{conn: conn} do
    topic = unique_topic()
    :ok = Phoenix.PubSub.subscribe(Donatex.PubSub, topic)

    first_tab = start_view(conn, topic, "shared-visitor")
    assert_join()
    second_tab = start_view(conn, topic, "shared-visitor")
    assert_join()
    second_visitor = start_view(conn, topic, "visitor-two")
    assert_join()
    third_visitor = start_view(conn, topic, "visitor-three")
    assert_join()

    for view <- [first_tab, second_tab, second_visitor, third_visitor] do
      assert_presence_count(view, 3)
    end

    stop_view(first_tab)
    assert_leave()

    for view <- [second_tab, second_visitor, third_visitor] do
      assert_presence_count(view, 3)
    end

    stop_view(second_tab)
    assert_leave()

    refute_presence_indicator(second_visitor)
    refute_presence_indicator(third_visitor)
  end

  test "keeps the donor form available when visitor_id is missing", %{conn: conn} do
    log =
      capture_log(fn ->
        {:ok, view, _html} =
          live_isolated(conn, DonateLive, session: %{"visitor_presence_topic" => unique_topic()})

        assert has_element?(view, "#donation-form")
        refute has_element?(view, "#visitor-presence-count")
      end)

    assert log =~ "Visitor presence tracking failed: :missing_visitor_id"
  end

  test "keeps the donor form available and stays fail-hidden after a tracker error", %{conn: conn} do
    topic = unique_topic()

    failed =
      with_visitor_presence(FailingTrack, fn ->
        log =
          capture_log(fn ->
            failed = start_view(conn, topic, "failed-visitor")
            assert has_element?(failed, "#donation-form")
            refute has_element?(failed, "#visitor-presence-count")
            send(self(), {:failed_view, failed})
          end)

        assert log =~ "Visitor presence tracking failed: :tracker_unavailable"
        assert_received {:failed_view, failed}
        failed
      end)

    :ok = Phoenix.PubSub.subscribe(Donatex.PubSub, topic)

    for visitor_id <- ["visitor-one", "visitor-two", "visitor-three"] do
      start_view(conn, topic, visitor_id)
      assert_join()
    end

    assert has_element?(failed, "#donation-form")
    refute_presence_indicator(failed)
  end

  test "keeps the donor form available when Presence.track exits", %{conn: conn} do
    topic = unique_topic()

    failed =
      with_visitor_presence(ExitingTrack, fn ->
        log =
          capture_log(fn ->
            failed = start_view(conn, topic, "exit-track-visitor")
            assert has_element?(failed, "#donation-form")
            refute has_element?(failed, "#visitor-presence-count")
            send(self(), {:exit_track_view, failed})
          end)

        assert log =~ "Visitor presence tracking failed: {:exit, :noproc}"
        assert_received {:exit_track_view, failed}
        failed
      end)

    :ok = Phoenix.PubSub.subscribe(Donatex.PubSub, topic)

    for visitor_id <- ["visitor-one", "visitor-two", "visitor-three"] do
      start_view(conn, topic, visitor_id)
      assert_join()
    end

    assert has_element?(failed, "#donation-form")
    refute_presence_indicator(failed)
  end

  test "keeps the donor form available when Presence.list exits", %{conn: conn} do
    topic = unique_topic()

    failed =
      with_visitor_presence(ExitingList, fn ->
        log =
          capture_log(fn ->
            failed = start_view(conn, topic, "exit-list-visitor")
            assert has_element?(failed, "#donation-form")
            refute has_element?(failed, "#visitor-presence-count")
            send(self(), {:exit_list_view, failed})
          end)

        assert log =~ "Visitor presence tracking failed: {:exit, :noproc}"
        assert_received {:exit_list_view, failed}
        failed
      end)

    :ok = Phoenix.PubSub.subscribe(Donatex.PubSub, topic)

    for visitor_id <- ["visitor-one", "visitor-two", "visitor-three"] do
      start_view(conn, topic, visitor_id)
      assert_join()
    end

    assert has_element?(failed, "#donation-form")
    refute_presence_indicator(failed)
  end

  defp start_view(conn, topic, visitor_id) do
    {:ok, view, _html} =
      live_isolated(conn, DonateLive,
        session: %{
          "visitor_id" => visitor_id,
          "visitor_presence_topic" => topic
        }
      )

    view
  end

  defp stop_view(view) do
    ref = Process.monitor(view.pid)
    GenServer.stop(view.pid, :normal)
    assert_receive {:DOWN, ^ref, :process, _, :normal}
  end

  defp assert_join, do: assert_presence_change(:joins)
  defp assert_leave, do: assert_presence_change(:leaves)

  defp assert_presence_change(change) do
    receive do
      %Phoenix.Socket.Broadcast{event: "presence_diff", payload: payload} ->
        if map_size(Map.fetch!(payload, change)) > 0 do
          :ok
        else
          assert_presence_change(change)
        end
    after
      1_000 -> flunk("expected Presence #{change} broadcast")
    end
  end

  defp assert_presence_count(view, count) do
    text = "#{count} orang sedang di halaman ini"

    assert_eventually(fn ->
      has_element?(view, "#visitor-presence-count", text)
    end)
  end

  defp refute_presence_indicator(view) do
    assert_eventually(fn ->
      _ = render(view)
      not has_element?(view, "#visitor-presence-count")
    end)
  end

  defp assert_eventually(fun, timeout_ms \\ 1_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_assert_eventually(fun, deadline)
  end

  defp do_assert_eventually(fun, deadline) do
    if fun.() do
      true
    else
      if System.monotonic_time(:millisecond) >= deadline do
        flunk("expected condition to become true before timeout")
      else
        receive do
        after
          10 -> do_assert_eventually(fun, deadline)
        end
      end
    end
  end

  defp with_visitor_presence(mod, fun) do
    original = Application.get_env(:donatex, :visitor_presence)
    Application.put_env(:donatex, :visitor_presence, mod)

    try do
      fun.()
    after
      restore_visitor_presence(original)
    end
  end

  defp restore_visitor_presence(nil), do: Application.delete_env(:donatex, :visitor_presence)
  defp restore_visitor_presence(mod), do: Application.put_env(:donatex, :visitor_presence, mod)

  defp unique_topic do
    "test:donate:visitors:#{System.unique_integer([:positive])}"
  end
end
