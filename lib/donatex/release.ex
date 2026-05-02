defmodule Donatex.Release do
  @moduledoc false

  @app :donatex

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _pid, _result} =
        Ecto.Migrator.with_repo(repo, fn repo ->
          Ecto.Migrator.run(repo, :up, all: true)
        end)
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
