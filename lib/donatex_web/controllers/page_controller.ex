defmodule DonatexWeb.PageController do
  use DonatexWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def redirect_to_root(conn, _params) do
    redirect(conn, to: ~p"/")
  end
end
