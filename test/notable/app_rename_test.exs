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

  test "DONATEX_* env names remain in runtime and example env files" do
    runtime = File.read!("config/runtime.exs")
    example = File.read!(".env.example")

    assert runtime =~ ~s|fetch_env!.("DONATEX_BASE_URL")|
    assert runtime =~ "DONATEX_BASE_URL is invalid"
    refute runtime =~ ~s|fetch_env!.("NOTABLE_BASE_URL")|

    assert example =~ "DONATEX_BASE_URL="
    refute example =~ "NOTABLE_BASE_URL="
  end

  test "CONTEXT.md glossary defines Brand as Notable" do
    context = File.read!("CONTEXT.md")

    assert context =~ "## Brand\n**Notable**."
    assert context =~ "host may remain Feedback-named"
  end
end
