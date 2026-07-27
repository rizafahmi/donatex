defmodule Donatex.Donations do
  @moduledoc """
  The donations context.
  """

  import Ecto.Query, warn: false

  require Logger

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
  Fallback lookup for when Mayar sends a different transaction ID at payment confirmation.
  Matches by amount (and optional donor_name) for pending donations.

  Returns the newest matching pending donation when unambiguous (exactly one pending
  at that amount, or donor_name disambiguates). Returns nil when ambiguous (multiple
  pending at same amount without donor_name) or no match.
  """
  def get_pending_donation_by_amount(amount, donor_name \\ nil)
      when is_integer(amount) and amount > 0 do
    case count_pending_by_amount(amount) do
      0 ->
        nil

      1 ->
        fetch_newest_pending_by_amount(amount)

      _count when is_binary(donor_name) and byte_size(donor_name) > 0 ->
        disambiguate_by_donor_name(amount, donor_name)

      count ->
        Logger.warning(
          "Mayar webhook ambiguous amount fallback: #{count} pending donations at amount=#{amount}, no donor_name to disambiguate"
        )

        nil
    end
  end

  defp disambiguate_by_donor_name(amount, donor_name) do
    named_count =
      Donation
      |> where(status: "pending")
      |> where(amount: ^amount)
      |> where([d], d.donor_name == ^donor_name)
      |> Repo.aggregate(:count)

    if named_count == 1 do
      fetch_newest_pending_by_amount_and_name(amount, donor_name)
    else
      Logger.warning(
        "Mayar webhook ambiguous amount fallback: donor_name=#{inspect(donor_name)} narrowed to #{named_count} at amount=#{amount} — still ambiguous"
      )

      nil
    end
  end

  defp fetch_newest_pending_by_amount(amount) do
    Donation
    |> where(status: "pending")
    |> where(amount: ^amount)
    |> order_by([d], desc: d.inserted_at, asc: d.id)
    |> limit(1)
    |> Repo.one()
  end

  defp fetch_newest_pending_by_amount_and_name(amount, donor_name) do
    Donation
    |> where(status: "pending")
    |> where(amount: ^amount)
    |> where([d], d.donor_name == ^donor_name)
    |> order_by([d], desc: d.inserted_at, asc: d.id)
    |> limit(1)
    |> Repo.one()
  end

  def count_pending_by_amount(amount) when is_integer(amount) and amount > 0 do
    Donation
    |> where(status: "pending")
    |> where(amount: ^amount)
    |> Repo.aggregate(:count)
  end

  @doc """
  Atomically claims a pending donation by amount (and optional donor_name) and
  updates its mayar_transaction_id to the confirmation ID — all in one operation.

  Returns `{:ok, donation}` when exactly one row is claimed, or
  `{:error, :ambiguous}` when multiple pending donations share the amount with
  no donor_name disambiguation, or `{:error, :not_found}` when no match.
  """
  def claim_fallback_donation(amount, donor_name, new_transaction_id)
      when is_integer(amount) and amount > 0 and is_binary(new_transaction_id) and
             byte_size(new_transaction_id) > 0 do
    case count_pending_by_amount(amount) do
      0 ->
        {:error, :not_found}

      1 ->
        do_atomic_claim(amount, nil, new_transaction_id)

      _count when donor_name == nil or donor_name == "" ->
        {:error, :ambiguous}

      _count ->
        claim_with_donor_name(amount, donor_name, new_transaction_id)
    end
  end

  defp claim_with_donor_name(amount, donor_name, new_transaction_id) do
    named_count =
      Donation
      |> where(status: "pending")
      |> where(amount: ^amount)
      |> where([d], d.donor_name == ^donor_name)
      |> Repo.aggregate(:count)

    if named_count == 1 do
      do_atomic_claim(amount, donor_name, new_transaction_id)
    else
      {:error, :ambiguous}
    end
  end

  defp do_atomic_claim(amount, donor_name, new_transaction_id) do
    candidate_id = fetch_candidate_id(amount, donor_name)

    if is_nil(candidate_id) do
      {:error, :not_found}
    else
      attempt_atomic_update(candidate_id, new_transaction_id, amount, donor_name)
    end
  end

  defp fetch_candidate_id(amount, donor_name) do
    Donation
    |> where(status: "pending")
    |> where(amount: ^amount)
    |> maybe_filter_donor_name(donor_name)
    |> order_by([d], desc: d.inserted_at, asc: d.id)
    |> limit(1)
    |> select([d], d.id)
    |> Repo.one()
  end

  defp attempt_atomic_update(candidate_id, new_transaction_id, amount, donor_name) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {count, _} =
      Donation
      |> where([d], d.id == ^candidate_id and d.status == "pending")
      |> Repo.update_all(
        set: [status: "paid", mayar_transaction_id: new_transaction_id, updated_at: now]
      )

    if count == 1 do
      {:ok, Repo.get!(Donation, candidate_id), true}
    else
      handle_update_race(candidate_id, new_transaction_id, amount, donor_name)
    end
  end

  defp handle_update_race(candidate_id, new_transaction_id, amount, donor_name) do
    case Repo.get(Donation, candidate_id) do
      %Donation{status: "paid", mayar_transaction_id: ^new_transaction_id} = donation ->
        {:ok, donation, false}

      _ ->
        pending_count =
          Donation
          |> where(status: "pending")
          |> where(amount: ^amount)
          |> maybe_filter_donor_name(donor_name)
          |> Repo.aggregate(:count)

        if pending_count > 0, do: {:error, :ambiguous}, else: {:error, :not_found}
    end
  end

  defp maybe_filter_donor_name(query, donor_name)
       when is_binary(donor_name) and byte_size(donor_name) > 0 do
    where(query, [d], d.donor_name == ^donor_name)
  end

  defp maybe_filter_donor_name(query, _donor_name), do: query

  def update_mayar_transaction_id(%Donation{} = donation, new_transaction_id)
      when is_binary(new_transaction_id) and byte_size(new_transaction_id) > 0 do
    donation
    |> Donation.changeset(%{mayar_transaction_id: new_transaction_id})
    |> Repo.update()
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
