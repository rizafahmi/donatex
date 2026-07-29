defmodule Notable.Reactions do
  @moduledoc """
  Reaction emoji pools for free-Note overlay floats.
  """

  @pools %{
    "bad" => ["😅", "🫠", "💤", "🙈"],
    "ok" => ["😐", "🤔", "😶", "🫤"],
    "good" => ["😊", "👍", "🙌", "💪"],
    "great" => ["🤩", "🔥", "🎉", "⭐"]
  }

  @doc """
  Returns the emoji pool for a reaction key, or nil when unknown.
  """
  def pool(reaction) when is_binary(reaction), do: Map.get(@pools, reaction)
  def pool(_reaction), do: nil

  @doc """
  Picks one random emoji from the reaction pool, or nil when unknown.
  """
  def pick_emoji(reaction) when is_binary(reaction) do
    case pool(reaction) do
      nil -> nil
      emojis -> Enum.random(emojis)
    end
  end

  def pick_emoji(_reaction), do: nil
end
