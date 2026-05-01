defmodule DonatexWeb.PageController do
  use DonatexWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
