defmodule Notable.ConfigTest do
  use ExUnit.Case, async: false

  setup do
    original_mayar = Application.get_env(:notable, :mayar)
    original_admin = Application.get_env(:notable, :admin)
    original_app = Application.get_env(:notable, :app)

    Application.put_env(:notable, :mayar,
      base_url: "https://api.example.test",
      api_key: "mayar_test_key",
      webhook_token: "mayar_webhook_test_token"
    )

    Application.put_env(:notable, :admin, username: "admin_test", password: "pass_test")
    Application.put_env(:notable, :app, base_url: "http://localhost:4000")

    on_exit(fn ->
      restore_env(:mayar, original_mayar)
      restore_env(:admin, original_admin)
      restore_env(:app, original_app)
    end)

    :ok
  end

  test "reads mayar config" do
    assert Notable.Config.mayar_base_url() == "https://api.example.test"
    assert Notable.Config.mayar_api_key() == "mayar_test_key"
    assert Notable.Config.mayar_webhook_token() == "mayar_webhook_test_token"
  end

  test "reads admin config" do
    assert Notable.Config.admin_username() == "admin_test"
    assert Notable.Config.admin_password() == "pass_test"
  end

  test "reads app config" do
    assert Notable.Config.base_url() == "http://localhost:4000"
  end

  defp restore_env(key, nil), do: Application.delete_env(:notable, key)
  defp restore_env(key, value), do: Application.put_env(:notable, key, value)
end
