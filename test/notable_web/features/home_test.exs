defmodule NotableWeb.HomeTest do
  use NotableWeb.ConnCase, async: true

  test "renders home page", %{conn: conn} do
    conn
    |> visit("/")
    |> assert_has("h1", donor_hero_headline())
  end
end
