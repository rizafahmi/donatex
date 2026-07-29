defmodule Notable.ReactionsTest do
  use ExUnit.Case, async: true

  alias Notable.Reactions

  @pools %{
    "bad" => ["😅", "🫠", "💤", "🙈"],
    "ok" => ["😐", "🤔", "😶", "🫤"],
    "good" => ["😊", "👍", "🙌", "💪"],
    "great" => ["🤩", "🔥", "🎉", "⭐"]
  }

  test "pool/1 returns the emoji pool for each reaction" do
    for {reaction, emojis} <- @pools do
      assert Reactions.pool(reaction) == emojis
    end
  end

  test "pool/1 returns nil for unknown reactions" do
    assert Reactions.pool("unknown") == nil
    assert Reactions.pool(nil) == nil
  end

  test "pick_emoji/1 returns an emoji from the reaction pool" do
    for {reaction, emojis} <- @pools do
      assert Reactions.pick_emoji(reaction) in emojis
    end
  end

  test "pick_emoji/1 returns nil for unknown reactions" do
    assert Reactions.pick_emoji("unknown") == nil
    assert Reactions.pick_emoji(nil) == nil
  end
end
