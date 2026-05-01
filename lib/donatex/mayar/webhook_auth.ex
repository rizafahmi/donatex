defmodule Donatex.Mayar.WebhookAuth do
  @moduledoc false

  alias Donatex.Config

  def valid_token?(token) when is_binary(token) do
    Plug.Crypto.secure_compare(token, Config.mayar_webhook_token())
  end

  def valid_token?(_token), do: false
end
