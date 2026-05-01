defmodule DonatexWeb.AdminLive do
  use DonatexWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h1>Admin</h1>
    </Layouts.app>
    """
  end
end
