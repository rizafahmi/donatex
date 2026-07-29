defmodule Notable.AppRenameTest do
  use ExUnit.Case, async: false

  alias Notable.Donations.Donation

  test "OTP app is :notable and Notable modules are loaded" do
    assert Mix.Project.config()[:app] == :notable
    assert Application.app_dir(:notable) |> File.dir?()
    assert Code.ensure_loaded?(Notable)
    assert Code.ensure_loaded?(NotableWeb)
    refute Code.ensure_loaded?(Donatex)
    refute Code.ensure_loaded?(DonatexWeb)
  end

  test "donations Ecto schema table name remains donations" do
    assert Donation.__schema__(:source) == "donations"
  end

  test "NOTABLE_* is canonical; DONATEX_* remains as documented alias" do
    runtime = File.read!("config/runtime.exs")
    example = File.read!(".env.example")
    ops = File.read!("docs/OPERATIONS.md")
    dev = File.read!("config/dev.exs")

    assert runtime =~ ~s|System.get_env("NOTABLE_BASE_URL")|
    assert runtime =~ ~s|System.get_env("DONATEX_BASE_URL")|
    assert runtime =~ "NOTABLE_BASE_URL is missing"
    assert runtime =~ "Temporary alias DONATEX_BASE_URL"

    assert dev =~ ~s|System.get_env("NOTABLE_BASE_URL")|
    assert dev =~ ~s|System.get_env("DONATEX_BASE_URL", "http://localhost:4000")|

    assert example =~ "NOTABLE_BASE_URL="
    assert example =~ "DONATEX_BASE_URL"

    assert ops =~ "`NOTABLE_BASE_URL` (canonical)"
    assert ops =~ "Temporary alias: `DONATEX_BASE_URL`"
  end

  test "base_url env resolution prefers NOTABLE_BASE_URL then DONATEX_BASE_URL alias" do
    notable_orig = System.get_env("NOTABLE_BASE_URL")
    donatex_orig = System.get_env("DONATEX_BASE_URL")

    on_exit(fn ->
      restore_env("NOTABLE_BASE_URL", notable_orig)
      restore_env("DONATEX_BASE_URL", donatex_orig)
    end)

    System.put_env("NOTABLE_BASE_URL", "https://notable.example")
    System.put_env("DONATEX_BASE_URL", "https://donatex.example")
    assert resolve_base_url_like_config() == "https://notable.example"

    System.delete_env("NOTABLE_BASE_URL")
    System.put_env("DONATEX_BASE_URL", "https://donatex-only.example")
    assert resolve_base_url_like_config() == "https://donatex-only.example"

    System.delete_env("NOTABLE_BASE_URL")
    System.delete_env("DONATEX_BASE_URL")
    assert resolve_base_url_like_config() == "http://localhost:4000"
  end

  # Mirrors config/dev.exs (and prod fallback order in config/runtime.exs).
  defp resolve_base_url_like_config do
    System.get_env("NOTABLE_BASE_URL") ||
      System.get_env("DONATEX_BASE_URL", "http://localhost:4000")
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)

  test "CONTEXT.md glossary defines Brand as Notable" do
    context = File.read!("CONTEXT.md")

    assert context =~ "## Brand\n**Notable**."
    assert context =~ "host may remain Feedback-named"
  end
end
