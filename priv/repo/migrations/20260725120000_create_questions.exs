defmodule Notable.Repo.Migrations.CreateQuestions do
  use Ecto.Migration

  def change do
    create table(:questions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :body, :string, null: false
      add :status, :string, null: false, default: "open"
      add :hidden_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:questions, [:hidden_at, :inserted_at, :id])

    create table(:question_votes, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :question_id, references(:questions, type: :binary_id, on_delete: :delete_all),
        null: false

      add :visitor_hash, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:question_votes, [:question_id, :visitor_hash])
    create index(:question_votes, [:question_id])
  end
end
