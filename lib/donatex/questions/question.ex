defmodule Donatex.Questions.Question do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(open answered)
  @max_body 500
  @max_name 64

  schema "questions" do
    field :name, :string
    field :body, :string
    field :status, :string, default: "open"
    field :hidden_at, :utc_datetime

    has_many :votes, Donatex.Questions.QuestionVote

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses
  def max_body, do: @max_body
  def max_name, do: @max_name

  @doc """
  Changeset for public question submission. Only the visitor-supplied
  `name` and `body` are cast; `status` and `hidden_at` are protected so
  the public form cannot set them.
  """
  def create_changeset(question, attrs) do
    question
    |> cast(attrs, [:name, :body])
    |> update_change(:name, &normalize_name/1)
    |> update_change(:body, &trim/1)
    |> validate_required([:body])
    |> validate_length(:name, max: @max_name)
    |> validate_length(:body, max: @max_body)
    |> validate_inclusion(:status, @statuses)
  end

  @doc """
  Changeset for administrative status transitions (open <-> answered).
  Does not touch body, name, or moderation state.
  """
  def status_changeset(question, attrs) do
    question
    |> cast(attrs, [:status])
    |> validate_required([:status])
    |> validate_inclusion(:status, @statuses)
  end

  @doc "Mark a question hidden by stamping `hidden_at` with the current UTC time."
  def hide_changeset(question) do
    change(question, hidden_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  @doc "Restore a hidden question by clearing `hidden_at`. Preserves open/answered status."
  def restore_changeset(question) do
    change(question, hidden_at: nil)
  end

  defp normalize_name(nil), do: nil

  defp normalize_name(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp trim(nil), do: nil
  defp trim(value) when is_binary(value), do: String.trim(value)
end
