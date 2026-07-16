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

  def format_idr(nil), do: ""

  def format_idr(amount) when is_integer(amount) and amount >= 0 do
    amount
    |> Integer.to_string()
    |> format_digits_with_thousands_separator()
  end

  def format_idr(amount) when is_integer(amount) do
    "-" <> format_idr(-amount)
  end

  defp format_digits_with_thousands_separator(digits) when is_binary(digits) do
    digits
    |> String.reverse()
    |> split_every_three_bytes()
    |> Enum.intersperse(".")
    |> IO.iodata_to_binary()
    |> String.reverse()
  end

  defp split_every_three_bytes(<<a, b, c, rest::binary>>) do
    [<<a, b, c>> | split_every_three_bytes(rest)]
  end

  defp split_every_three_bytes(<<>>), do: []
  defp split_every_three_bytes(rest), do: [rest]

  def present_message?(message) when is_binary(message), do: byte_size(String.trim(message)) > 0
  def present_message?(_message), do: false
end
