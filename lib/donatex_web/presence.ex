defmodule DonatexWeb.Presence do
  @moduledoc "Tracks ephemeral browser-session presence on the donor page."

  use Phoenix.Presence,
    otp_app: :donatex,
    pubsub_server: Donatex.PubSub
end
