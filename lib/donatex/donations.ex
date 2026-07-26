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
  Atomically claims a pending donation by amount (and optional donor_name) as paid.

  Sets the new Mayar transaction ID in the same `UPDATE … WHERE status = 'pending'`
  statement, so the transaction-id update and paid transition cannot be split by a
  crash or a concurrent webhook. Fails closed with `{:error, :ambiguous}` when more
  than one pending donation matches the criteria, preventing remapped correlation
  under concurrent same-amount payments.

  Returns:
    * `{:ok, donation, true}`  — claimed and marked paid (broadcast once)
    * `{:ok, donation, false}` — already paid by a concurrent delivery (no broadcast)
    * `{:error, :not_found}`   — no matching pending donation (orphan payment)
    * `{:error, :ambiguous}`   — multiple matching pending donations, fail closed
  """
  def claim_pending_by_amount_with_change(amount, donor_name \\ nil, new_transaction_id)
      when is_integer(amount) and amount > 0 and is_binary(new_transaction_id) and
             byte_size(new_transaction_id) > 0 do
    case list_pending_by_amount_and_donor(amount, donor_name) do
      [] ->
        {:error, :not_found}

      [donation] ->
        claim_with_transaction_id_update(donation, new_transaction_id)

      _multiple ->
        {:error, :ambiguous}
    end
  end

  defp list_pending_by_amount_and_donor(amount, donor_name) do
    query =
      Donation
      |> where(status: "pending")
      |> where(amount: ^amount)
      |> order_by([d], asc: d.inserted_at, asc: d.id)

    if donor_name && byte_size(donor_name) > 0 do
      query |> where([d], d.donor_name == ^donor_name) |> Repo.all()
    else
      Repo.all(query)
    end
  end

  @doc """
  Atomically updates a donation's Mayar transaction ID and marks it paid.

  Uses `UPDATE … WHERE status = 'pending'` so concurrent webhook deliveries produce
  exactly one winner (`changed? = true`). The transaction-id update and paid
  transition happen in a single SQL statement, preventing orphaned state between
  steps.
  """
  def claim_with_transaction_id_update(%Donation{status: "paid"} = donation, _new_transaction_id),
    do: {:ok, donation, false}

  def claim_with_transaction_id_update(%Donation{id: id} = donation, new_transaction_id)
      when is_binary(id) and is_binary(new_transaction_id) and byte_size(new_transaction_id) > 0 do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {count, _} =
      Donation
      |> where([d], d.id == ^id and d.status == "pending")
      |> Repo.update_all(
        set: [status: "paid", mayar_transaction_id: new_transaction_id, updated_at: now]
      )

    case count do
      1 ->
        {:ok,
         %{donation | status: "paid", mayar_transaction_id: new_transaction_id, updated_at: now},
         true}

      0 ->
        paid_claim_result(id)
    end
  end

  def claim_with_transaction_id_update(_donation, _new_transaction_id),
    do: {:error, :invalid_args}

  defp paid_claim_result(id) do
    case Repo.get(Donation, id) do
      %Donation{status: "paid"} = paid -> {:ok, paid, false}
      nil -> {:error, :not_found}
      %Donation{} -> {:error, :invalid_state}
    end
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
        paid_claim_result(id)
    end
  end

  def mark_paid_with_change(_donation), do: {:error, :invalid_donation}

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
  rescue
    _error in [DBConnection.ConnectionError, Exqlite.Error] ->
      {:error, :persistence_failed}
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
