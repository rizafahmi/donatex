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

  def update_mayar_transaction_id(%Donation{} = donation, new_transaction_id)
      when is_binary(new_transaction_id) and byte_size(new_transaction_id) > 0 do
    donation
    |> Donation.changeset(%{mayar_transaction_id: new_transaction_id})
    |> Repo.update()
  end

  @doc """
  Atomically claims a unique pending tip via amount fallback correlation.

  When Mayar's paid webhook uses a different transaction id than the QR create
  response, remaps `mayar_transaction_id` and marks the tip paid in a single
  `UPDATE … WHERE status = 'pending'`.

  Fails closed unless exactly one pending tip matches `amount` (and optional
  `donor_name` when present). Concurrent same-amount payments therefore never
  silently remap the wrong pending tip.
  """
  def claim_pending_by_amount_as_paid(amount, new_transaction_id, donor_name \\ nil)

  def claim_pending_by_amount_as_paid(amount, new_transaction_id, donor_name)
      when is_integer(amount) and amount > 0 and is_binary(new_transaction_id) and
             byte_size(new_transaction_id) > 0 do
    case already_paid_by_transaction_id(new_transaction_id) do
      %Donation{} = paid ->
        {:ok, paid, false}

      nil ->
        case Repo.transaction(fn ->
               claim_pending_by_amount_in_tx(amount, new_transaction_id, donor_name)
             end) do
          {:ok, {donation, changed?}} -> {:ok, donation, changed?}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def claim_pending_by_amount_as_paid(_amount, _new_transaction_id, _donor_name),
    do: {:error, :invalid_attrs}

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

  defp claim_pending_by_amount_in_tx(amount, new_transaction_id, donor_name) do
    case pending_amount_matches(amount, donor_name) do
      [] ->
        Repo.rollback(:not_found)

      [_first, _second | _] ->
        Repo.rollback(:ambiguous)

      [%Donation{id: id} = donation] ->
        claim_unique_pending_amount_match(donation, id, amount, new_transaction_id)
    end
  end

  defp already_paid_by_transaction_id(mayar_transaction_id) do
    case Repo.get_by(Donation, mayar_transaction_id: mayar_transaction_id) do
      %Donation{status: "paid"} = paid -> paid
      _ -> nil
    end
  end

  defp pending_amount_matches(amount, donor_name) do
    Donation
    |> where([d], d.status == "pending" and d.amount == ^amount)
    |> maybe_filter_donor_name(donor_name)
    |> order_by([d], asc: d.inserted_at, asc: d.id)
    |> limit(2)
    |> Repo.all()
  end

  defp maybe_filter_donor_name(query, donor_name)
       when is_binary(donor_name) and byte_size(donor_name) > 0 do
    where(query, [d], d.donor_name == ^donor_name)
  end

  defp maybe_filter_donor_name(query, _donor_name), do: query

  defp claim_unique_pending_amount_match(donation, id, amount, new_transaction_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {count, _} =
      Donation
      |> where([d], d.id == ^id and d.status == "pending" and d.amount == ^amount)
      |> Repo.update_all(
        set: [
          mayar_transaction_id: new_transaction_id,
          status: "paid",
          updated_at: now
        ]
      )

    case count do
      1 ->
        {%{donation | mayar_transaction_id: new_transaction_id, status: "paid", updated_at: now},
         true}

      0 ->
        case already_paid_by_transaction_id(new_transaction_id) do
          %Donation{} = paid -> {paid, false}
          nil -> Repo.rollback(:not_found)
        end
    end
  rescue
    error in [Ecto.ConstraintError, Exqlite.Error] ->
      if unique_mayar_transaction_id_error?(error) do
        Repo.rollback(:transaction_id_taken)
      else
        reraise error, __STACKTRACE__
      end
  end

  defp unique_mayar_transaction_id_error?(%Ecto.ConstraintError{
         constraint: "donations_mayar_transaction_id_index"
       }),
       do: true

  defp unique_mayar_transaction_id_error?(%Ecto.ConstraintError{constraint: constraint})
       when is_binary(constraint),
       do: String.contains?(constraint, "mayar_transaction_id")

  defp unique_mayar_transaction_id_error?(%Exqlite.Error{} = error),
    do: String.contains?(Exception.message(error), "mayar_transaction_id")

  defp unique_mayar_transaction_id_error?(_error), do: false
end
