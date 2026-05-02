defmodule DonatexWeb.DonationPresenter do
  @moduledoc false

  alias Donatex.Donations.Donation

  def payload(%Donation{} = donation) do
    %{
      id: donation.id,
      mayar_transaction_id: donation.mayar_transaction_id,
      donor_name: donation.donor_name,
      amount: donation.amount,
      message: donation.message,
      inserted_at: donation.inserted_at
    }
  end

  def format_idr(amount) when is_integer(amount) do
    amount
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&(Enum.reverse(&1) |> Enum.join()))
    |> Enum.reverse()
    |> Enum.join(".")
  end

  def present_message?(message) when is_binary(message), do: byte_size(String.trim(message)) > 0
  def present_message?(_message), do: false
end
