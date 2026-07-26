defmodule Donatex.Donations do
  @moduledoc """
  The donations context.
  """

  import Ecto.Query, warn: false

  alias Donatex.Donations.Donation
  alias Donatex.Repo

  def list_donations(filter \\ :paid)

  def list_donations(:all) do
    Donation
    |> order_by([d], desc: d.inserted_at, desc: d.id)
    |> Repo.all()
  end

  def list_donations("all"), do: list_donations(:all)

  def list_donations(:paid) do
    Donation
    |> where([d], d.status == "paid")
    |> order_by([d], desc: d.inserted_at, desc: d.id)
    |> Repo.all()
  end

  def list_donations("paid"), do: list_donations(:paid)

  def list_donations(:pending) do
    Donation
    |> where([d], d.status == "pending")
    |> order_by([d], desc: d.inserted_at, desc: d.id)
    |> Repo.all()
  end

  def list_donations("pending"), do: list_donations(:pending)

  def list_donations(:tips) do
    Donation
    |> where([d], not is_nil(d.amount))
    |> order_by([d], desc: d.inserted_at, desc: d.id)
    |> Repo.all()
  end

  def list_donations("tips"), do: list_donations(:tips)

  def list_donations(:feedback) do
    Donation
    |> where([d], d.status == "sent")
    |> order_by([d], desc: d.inserted_at, desc: d.id)
    |> Repo.all()
  end

  def list_donations("feedback"), do: list_donations(:feedback)

  def create_pending_donation(attrs) when is_map(attrs) do
    attrs = Map.drop(attrs, [:status, :alerted, "status", "alerted"])

    %Donation{}
    |> Donation.changeset(attrs)
    |> Repo.insert()
  end

  def create_pending_donation(_attrs), do: {:error, :invalid_attrs}

  def create_feedback(attrs) when is_map(attrs) do
    attrs =
      attrs
      |> Map.drop([:mayar_transaction_id, :amount, :status, :alerted])
      |> Map.merge(%{status: "sent", alerted: true})

    %Donation{}
    |> Donation.changeset(attrs)
    |> Repo.insert()
  end

  def create_feedback(_attrs), do: {:error, :invalid_attrs}

  def create_donation(attrs) do
    create_pending_donation(attrs)
  end

  def get_donation_by_mayar_transaction_id(mayar_transaction_id)
      when is_binary(mayar_transaction_id) and byte_size(mayar_transaction_id) > 0 do
    Repo.get_by(Donation, mayar_transaction_id: mayar_transaction_id)
  end

  def get_donation_by_mayar_transaction_id(_mayar_transaction_id), do: nil

  @doc """
  Atomically claims the unique pending donation matching an amount and optional donor name.
  """
  def claim_pending_donation_by_amount(amount, donor_name, new_transaction_id)
      when is_integer(amount) and amount > 0 and is_binary(new_transaction_id) and
             byte_size(new_transaction_id) > 0 do
    candidates =
      Donation
      |> where(status: "pending")
      |> where(amount: ^amount)

    candidates =
      if donor_name && byte_size(donor_name) > 0 do
        where(candidates, [d], d.donor_name == ^donor_name)
      else
        candidates
      end

    unique_candidate_id =
      candidates
      |> group_by([d], d.status)
      |> having([d], count(d.id) == 1)
      |> select([d], max(d.id))

    Donation
    |> where([d], d.status == "pending" and d.id in subquery(unique_candidate_id))
    |> do_claim_pending_donation(new_transaction_id)
  end

  def claim_pending_donation(%Donation{id: id}, new_transaction_id)
      when is_binary(new_transaction_id) and byte_size(new_transaction_id) > 0 do
    Donation
    |> where([d], d.id == ^id and d.status == "pending")
    |> do_claim_pending_donation(new_transaction_id)
  end

  def get_donation_by_id(id) when is_binary(id) and byte_size(id) > 0 do
    Repo.get(Donation, id)
  end

  def get_donation_by_id(_id), do: nil

  def mark_paid_by_mayar_transaction_id_with_change(mayar_transaction_id)
      when is_binary(mayar_transaction_id) and byte_size(mayar_transaction_id) > 0 do
    case Repo.get_by(Donation, mayar_transaction_id: mayar_transaction_id) do
      nil ->
        {:error, :not_found}

      donation ->
        mark_paid_with_change(donation)
    end
  end

  def mark_paid_by_mayar_transaction_id_with_change(_mayar_transaction_id),
    do: {:error, :invalid_transaction_id}

  @doc """
  Atomically claims a pending donation as paid.

  Uses `UPDATE … WHERE status = 'pending'` so concurrent webhook deliveries
  produce exactly one winner (`changed? = true`). Losers see an already-paid
  row and return `changed? = false` without a second broadcast.
  """
  def mark_paid_with_change(%Donation{status: "paid"} = donation), do: {:ok, donation, false}

  def mark_paid_with_change(%Donation{id: id} = donation) when is_binary(id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {count, _} =
      Donation
      |> where([d], d.id == ^id and d.status == "pending")
      |> Repo.update_all(set: [status: "paid", updated_at: now])

    case count do
      1 ->
        # Claim already persisted; do not re-get (nil would drop the live broadcast).
        {:ok, %{donation | status: "paid", updated_at: now}, true}

      0 ->
        case Repo.get(Donation, id) do
          %Donation{status: "paid"} = paid -> {:ok, paid, false}
          nil -> {:error, :not_found}
          %Donation{} -> {:error, :invalid_state}
        end
    end
  end

  def mark_paid_with_change(_donation), do: {:error, :invalid_donation}

  defp do_claim_pending_donation(query, new_transaction_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    query
    |> select([d], d)
    |> Repo.update_all(
      set: [
        mayar_transaction_id: new_transaction_id,
        status: "paid",
        updated_at: now
      ]
    )
    |> case do
      {1, [donation]} -> {:ok, donation}
      {0, []} -> {:error, :not_found_or_ambiguous}
    end
  end

  def mark_paid_by_mayar_transaction_id(mayar_transaction_id)
      when is_binary(mayar_transaction_id) and byte_size(mayar_transaction_id) > 0 do
    with {:ok, donation, _changed?} <-
           mark_paid_by_mayar_transaction_id_with_change(mayar_transaction_id) do
      {:ok, donation}
    end
  end

  def mark_paid_by_mayar_transaction_id(_mayar_transaction_id),
    do: {:error, :invalid_transaction_id}

  def get_donation(id), do: get_donation_by_id(id)

  def list_paid_unalerted_donations do
    Donation
    |> where([d], d.status == "paid" and not d.alerted)
    |> order_by([d], asc: d.inserted_at, asc: d.id)
    |> Repo.all()
  end

  def mark_donation_alerted(%Donation{status: "paid", alerted: true} = donation),
    do: {:ok, donation}

  def mark_donation_alerted(%Donation{status: "paid"} = donation) do
    donation
    |> Donation.changeset(%{alerted: true})
    |> Repo.update()
  end

  def mark_donation_alerted(%Donation{}), do: {:error, :invalid_state}

  def mark_donation_alerted_by_id(id) when is_binary(id) and byte_size(id) > 0 do
    case Repo.get(Donation, id) do
      nil -> {:error, :not_found}
      donation -> mark_donation_alerted(donation)
    end
  end

  def mark_donation_alerted_by_id(_id), do: {:error, :invalid_id}

  def get_donation_stats do
    results =
      Donation
      |> group_by([d], d.status)
      |> select([d], {d.status, count(d.id), sum(d.amount)})
      |> Repo.all()

    Enum.reduce(results, %{paid_count: 0, paid_sum: 0, pending_count: 0}, fn
      {"paid", count, sum}, acc ->
        %{acc | paid_count: count, paid_sum: sum || 0}

      {"pending", count, _sum}, acc ->
        %{acc | pending_count: count}

      _, acc ->
        acc
    end)
  end
end
