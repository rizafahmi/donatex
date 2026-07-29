defmodule NotableWeb.OverlayComponents do
  @moduledoc """
  Shared flying-emoji feedback reaction components used by overlay pages.
  """

  use NotableWeb, :html

  alias Notable.Reactions

  @doc """
  Renders the flying emoji floats map.
  """
  attr :floats, :map, required: true

  def floats(assigns) do
    ~H"""
    <div
      :for={{id, float} <- @floats}
      id={"obs-float-#{id}"}
      class="obs-float-emoji"
      style={float_style(float)}
      aria-hidden="true"
    >
      {float.emoji}
    </div>
    """
  end

  @doc """
  Builds a float map for an accepted free Note donation, or `nil` if the
  reaction has no emoji.
  """
  def build_float(%{id: id, reaction: reaction}) do
    case Reactions.pick_emoji(reaction) do
      nil ->
        nil

      emoji ->
        %{
          id: id,
          emoji: emoji,
          start_x: Enum.random(8..85),
          drift_x: Enum.random(-18..18),
          duration_ms: Enum.random(3_000..4_000)
        }
    end
  end

  @doc """
  Adds a float for the given donation to the socket's `:floats` assign and
  schedules its auto-dismissal. Returns the socket unchanged when the
  donation has no emoji.
  """
  def add_float(socket, donation) do
    case build_float(donation) do
      nil ->
        socket

      float ->
        Process.send_after(self(), {:dismiss_float, float.id}, float.duration_ms)
        update(socket, :floats, &Map.put(&1, float.id, float))
    end
  end

  @doc """
  Removes a float by id from the socket's `:floats` assign.
  """
  def dismiss_float(socket, id) do
    update(socket, :floats, &Map.delete(&1, id))
  end

  defp float_style(float) do
    [
      "--float-start-x: #{float.start_x}%;",
      "--float-drift-x: #{float.drift_x}vw;",
      "--float-duration: #{float.duration_ms}ms;"
    ]
  end
end
