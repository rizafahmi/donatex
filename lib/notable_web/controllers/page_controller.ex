defmodule NotableWeb.PageController do
  use NotableWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def redirect_to_root(conn, _params) do
    conn
    |> put_status(:moved_permanently)
    |> redirect(to: ~p"/")
  end
end
