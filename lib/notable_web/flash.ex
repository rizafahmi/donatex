defmodule NotableWeb.Flash do
  @moduledoc false

  import Phoenix.Component, only: [assign: 3]

  def on_mount(:default, _params, _session, socket) do
    {:cont, assign(socket, :flash_generations, %{})}
  end

  def put_flash(socket, kind, message) do
    key = to_string(kind)

    socket = Phoenix.LiveView.put_flash(socket, kind, message)
    generations = Map.update(socket.assigns.flash_generations, key, 1, &(&1 + 1))

    assign(socket, :flash_generations, generations)
  end
end
