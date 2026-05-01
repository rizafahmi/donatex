defmodule Donatex.Donations do
  @moduledoc """
  The donations context.
  """

  import Ecto.Query, warn: false

  alias Donatex.Donations.Donation
  alias Donatex.Repo

  def list_donations do
    Donation
    |> order_by([d], asc: d.inserted_at, asc: d.id)
    |> Repo.all()
  end

  def create_pending_donation(attrs) when is_map(attrs) do
    attrs = Map.drop(attrs, [:status, :alerted, "status", "alerted"])

    %Donation{}
    |> Donation.changeset(attrs)
    |> Repo.insert()
  end

  def create_pending_donation(_attrs), do: {:error, :invalid_attrs}

  def create_donation(attrs) do
    create_pending_donation(attrs)
  end

  def mark_paid_by_mayar_transaction_id(mayar_transaction_id)
      when is_binary(mayar_transaction_id) and byte_size(mayar_transaction_id) > 0 do
    case Repo.get_by(Donation, mayar_transaction_id: mayar_transaction_id) do
      nil ->
        {:error, :not_found}

      %Donation{status: "paid"} = donation ->
        {:ok, donation}

      donation ->
        donation
        |> Donation.changeset(%{status: "paid"})
        |> Repo.update()
    end
  end

  def mark_paid_by_mayar_transaction_id(_mayar_transaction_id),
    do: {:error, :invalid_transaction_id}

  def list_paid_unalerted_donations do
    Donation
    |> where([d], d.status == "paid" and not d.alerted)
    |> order_by([d], asc: d.inserted_at, asc: d.id)
    |> Repo.all()
  end

  def mark_donation_alerted(%Donation{} = donation) do
    case donation do
      %Donation{status: "paid", alerted: true} ->
        {:ok, donation}

      %Donation{status: "paid"} ->
        donation
        |> Donation.changeset(%{alerted: true})
        |> Repo.update()

      _ ->
        {:error, :invalid_state}
    end
  end
end
