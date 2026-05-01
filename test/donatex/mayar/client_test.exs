defmodule Donatex.Mayar.ClientTest do
  use ExUnit.Case, async: false

  alias Donatex.Mayar.Client

  defmodule TestImpl do
    @behaviour Client.Impl

    @impl true
    def create_qr(amount_idr) do
      {:ok,
       %Client.DynamicQr{
         mayar_transaction_id: "txn_test_#{amount_idr}",
         amount: amount_idr,
         qr_image_url: "https://example.invalid/qr/#{amount_idr}",
         expires_at: nil
       }}
    end
  end

  setup do
    original = Application.get_env(:donatex, :mayar_client_impl)

    on_exit(fn ->
      case original do
        nil -> Application.delete_env(:donatex, :mayar_client_impl)
        _ -> Application.put_env(:donatex, :mayar_client_impl, original)
      end
    end)

    :ok
  end

  test "create_qr/1 validates amount" do
    assert {:error, :invalid_amount} = Client.create_qr(0)
    assert {:error, :invalid_amount} = Client.create_qr(-1)
    assert {:error, :invalid_amount} = Client.create_qr("10_000")
  end

  test "create_qr/1 delegates to configured implementation" do
    Application.put_env(:donatex, :mayar_client_impl, TestImpl)

    assert {:ok,
            %Client.DynamicQr{
              mayar_transaction_id: "txn_test_10000",
              amount: 10_000,
              qr_image_url: "https://example.invalid/qr/10000",
              expires_at: nil
            }} = Client.create_qr(10_000)
  end

  test "create_qr/1 defaults to stub implementation when none configured" do
    Application.delete_env(:donatex, :mayar_client_impl)
    assert {:error, :not_implemented} = Client.create_qr(10_000)
  end
end
