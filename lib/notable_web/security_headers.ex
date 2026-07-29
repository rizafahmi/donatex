defmodule NotableWeb.SecurityHeaders do
  @moduledoc false

  def headers do
    %{
      "content-security-policy" =>
        "default-src 'self'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; img-src 'self' data: https:; font-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self' 'sha256-EVYDGHSK/rxwzu+pTaoqPoOXtDc/oiZPntzv6wWXhj8='; connect-src 'self' ws: wss:; object-src 'none'",
      "permissions-policy" => "camera=(), microphone=(), geolocation=()",
      "referrer-policy" => "strict-origin-when-cross-origin",
      "x-content-type-options" => "nosniff",
      "x-frame-options" => "DENY",
      "strict-transport-security" => "max-age=31536000; includeSubDomains"
    }
  end
end
