defmodule DonatexWeb.SecurityHeaders do
  @moduledoc false

  def headers do
    %{
      "content-security-policy" =>
        "default-src 'self'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; img-src 'self' data: https:; font-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self' 'sha256-upezcioBKi0E/iqFFMYwRsb+SJt3JiqGq3KOHTBgB1M='; connect-src 'self' ws: wss:; object-src 'none'",
      "permissions-policy" => "camera=(), microphone=(), geolocation=()",
      "referrer-policy" => "strict-origin-when-cross-origin",
      "x-frame-options" => "DENY"
    }
  end
end
