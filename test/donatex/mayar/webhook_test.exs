defmodule Donatex.Mayar.WebhookTest do
  use ExUnit.Case, async: true

  alias Donatex.Mayar.Webhook

  describe "parse/1" do
    test "extracts payment.received fields from the documented payload" do
      assert {:ok, parsed} =
               Webhook.parse(%{
                 "event" => "payment.received",
                 "data" => %{
                   "transactionId" => "tx-123",
                   "customerName" => "  Riza  ",
                   "amount" => 25_000,
                   "transactionStatus" => "paid"
                 }
               })

      assert parsed.event == "payment.received"
      assert parsed.mayar_transaction_id == "tx-123"
      assert parsed.donor_name == "Riza"
      assert parsed.amount == 25_000
      assert parsed.transaction_status == "paid"
    end

    test "ignores non payment.received events" do
      assert :ignore =
               Webhook.parse(%{
                 "event" => "payment.pending",
                 "data" => %{
                   "transactionId" => "tx-123",
                   "amount" => 25_000,
                   "transactionStatus" => "pending"
                 }
               })
    end

    test "rejects payloads missing required fields" do
      assert {:error, {:missing_field, :mayar_transaction_id}} =
               Webhook.parse(%{
                 "event" => "payment.received",
                 "data" => %{
                   "customerName" => "Riza",
                   "amount" => 25_000,
                   "transactionStatus" => "paid"
                 }
               })
    end

    test "rejects payloads with non-map data" do
      assert {:error, :invalid_payload} =
               Webhook.parse(%{
                 "event" => "payment.received",
                 "data" => "oops"
               })
    end

    test "falls back to documented alternate field names" do
      assert {:ok, parsed} =
               Webhook.parse(%{
                 "event" => "payment.received",
                 "data" => %{
                   "id" => "tx-456",
                   "customerName" => "Donor",
                   "amount" => "30000",
                   "status" => "SUCCESS"
                 }
               })

      assert parsed.mayar_transaction_id == "tx-456"
      assert parsed.amount == 30_000
      assert parsed.transaction_status == "SUCCESS"
    end
  end
end
