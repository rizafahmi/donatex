defmodule DonatexWeb.LiveAdminAuth do
  @moduledoc """
  LiveView mount gate for admin routes.

  `Plug.BasicAuth` only guards the initial HTTP request; a LiveView websocket
  mount or reconnect never re-runs the plug pipeline. This `on_mount` callback
  closes that gap: the admin plug stamps `admin_authenticated` into the session
  on successful Basic Auth, and this callback rejects any admin LiveView mount
  that lacks the flag.
  """

  use DonatexWeb, :verified_routes

  def on_mount(:default, _params, session, socket) do
    if session["admin_authenticated"] do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    end
  end
end
