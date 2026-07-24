defmodule DonatexWeb.Plugs.SEO do
  @moduledoc """
  Plug to assign SEO-related metadata (description, robots, canonical URL)
  to the connection so they are available when rendering the root layout.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    base_url =
      (Application.get_env(:donatex, :app)[:base_url] || "https://feedback.rizafahmi.com")
      |> String.trim_trailing("/")

    path = conn.request_path

    case path do
      "/" ->
        conn
        |> assign(
          :meta_description,
          "Kirim masukan, saran, atau pesan secara gratis. Anda juga dapat memberikan tip apresiasi via QRIS untuk mendukung kreator."
        )
        |> assign(:meta_robots, "index, follow, max-snippet:150, max-image-preview:large")
        |> assign(:canonical_url, base_url <> "/")

      "/overlay" ->
        conn
        |> assign(
          :meta_description,
          "OBS stream overlay page for displaying live alerts and emoji reactions."
        )
        |> assign(:meta_robots, "noindex, nofollow")
        |> assign(:canonical_url, base_url <> "/overlay")

      "/admin" ->
        conn
        |> assign(:meta_description, "Administrative console for managing notes and tips.")
        |> assign(:meta_robots, "noindex, nofollow")
        |> assign(:canonical_url, base_url <> "/admin")

      _ ->
        conn
    end
  end
end
