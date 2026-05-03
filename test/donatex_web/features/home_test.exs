defmodule DonatexWeb.HomeTest do
  use DonatexWeb.ConnCase, async: true

  test "renders home page", %{conn: conn} do
    conn
    |> visit("/")
    |> assert_has("h1", "Donatex")
  end
end
