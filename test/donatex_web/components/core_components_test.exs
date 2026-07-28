defmodule DonatexWeb.CoreComponentsTest do
  use DonatexWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import DonatexWeb.CoreComponents

  describe "button/1" do
    test "passes through type=submit for form actions" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button type="submit" id="submit-btn">Kirim</.button>
        """)

      assert html =~ ~s(id="submit-btn")
      assert html =~ ~s(type="submit")
      assert html =~ "Kirim"
    end

    test "passes through type=button for non-submit actions" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button type="button" id="plain-btn" phx-click="noop">Kembali</.button>
        """)

      assert html =~ ~s(id="plain-btn")
      assert html =~ ~s(type="button")
      assert html =~ "Kembali"
    end
  end
end
