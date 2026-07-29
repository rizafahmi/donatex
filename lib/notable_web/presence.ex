defmodule NotableWeb.Presence do
  @moduledoc "Tracks ephemeral browser-session presence on the donor page."

  use Phoenix.Presence,
    otp_app: :notable,
    pubsub_server: Notable.PubSub
end
