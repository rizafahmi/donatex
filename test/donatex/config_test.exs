defmodule Donatex.ConfigTest do
  use ExUnit.Case, async: false

  setup do
    original_mayar = Application.get_env(:donatex, :mayar)
    original_overlay = Application.get_env(:donatex, :overlay)
    original_admin = Application.get_env(:donatex, :admin)
    original_app = Application.get_env(:donatex, :app)

    Application.put_env(:donatex, :mayar,
      base_url: "https://api.example.test",
      api_key: "mayar_test_key",
      webhook_token: "mayar_webhook_test_token"
    )

    Application.put_env(:donatex, :overlay, token: "overlay_test_token")
    Application.put_env(:donatex, :admin, username: "admin_test", password: "pass_test")
    Application.put_env(:donatex, :app, base_url: "http://localhost:4000")

    on_exit(fn ->
      restore_env(:mayar, original_mayar)
      restore_env(:overlay, original_overlay)
      restore_env(:admin, original_admin)
      restore_env(:app, original_app)
    end)

    :ok
  end

  test "reads mayar config" do
    assert Donatex.Config.mayar_base_url() == "https://api.example.test"
    assert Donatex.Config.mayar_api_key() == "mayar_test_key"
    assert Donatex.Config.mayar_webhook_token() == "mayar_webhook_test_token"
  end

  test "reads overlay config" do
    assert Donatex.Config.overlay_token() == "overlay_test_token"
  end

  test "reads admin config" do
    assert Donatex.Config.admin_username() == "admin_test"
    assert Donatex.Config.admin_password() == "pass_test"
  end

  test "reads app config" do
    assert Donatex.Config.base_url() == "http://localhost:4000"
  end

  test "raises on missing config key" do
    Application.put_env(:donatex, :overlay, [])

    assert_raise ArgumentError, fn ->
      Donatex.Config.overlay_token()
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:donatex, key)
  defp restore_env(key, value), do: Application.put_env(:donatex, key, value)
end
