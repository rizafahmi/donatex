defmodule Donatex.Config do
  @moduledoc false

  def mayar_base_url, do: fetch_binary!(:mayar, :base_url)

  def mayar_api_key, do: fetch_binary!(:mayar, :api_key)

  def mayar_webhook_token, do: fetch_binary!(:mayar, :webhook_token)

  def overlay_token, do: fetch_binary!(:overlay, :token)

  def admin_username, do: fetch_binary!(:admin, :username)

  def admin_password, do: fetch_binary!(:admin, :password)

  def base_url, do: fetch_binary!(:app, :base_url)

  defp fetch_binary!(group, key) do
    group_config = Application.get_env(:donatex, group) || []

    value =
      case group_config do
        config when is_list(config) -> Keyword.get(config, key)
        config when is_map(config) -> Map.get(config, key)
      end

    if is_binary(value) and byte_size(value) > 0 do
      value
    else
      raise ArgumentError,
            "missing config :donatex, #{inspect(group)} #{inspect(key)} (expected a non-empty string)"
    end
  end
end
