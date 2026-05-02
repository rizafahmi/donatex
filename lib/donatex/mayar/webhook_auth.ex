defmodule Donatex.Mayar.WebhookAuth do
  @moduledoc false

  alias Donatex.Config

  def valid_token?(token) when is_binary(token) do
    Plug.Crypto.secure_compare(
      normalize_token(token),
      normalize_token(Config.mayar_webhook_token())
    )
  end

  def valid_token?(_token), do: false

  defp normalize_token(token) when is_binary(token), do: String.trim(token)
end
