defmodule DonatexWeb.DonationPresenterTest do
  use ExUnit.Case, async: true

  alias DonatexWeb.DonationPresenter

  describe "format_idr/1" do
    test "formats nil as an empty string" do
      assert DonationPresenter.format_idr(nil) == ""
    end

    test "formats small integers without separators" do
      assert DonationPresenter.format_idr(0) == "0"
      assert DonationPresenter.format_idr(10) == "10"
      assert DonationPresenter.format_idr(999) == "999"
    end

    test "formats thousands with dot separators" do
      assert DonationPresenter.format_idr(1_000) == "1.000"
      assert DonationPresenter.format_idr(10_000) == "10.000"
      assert DonationPresenter.format_idr(1_000_000) == "1.000.000"
      assert DonationPresenter.format_idr(25_000_000) == "25.000.000"
    end

    test "formats negative integers with a leading hyphen" do
      assert DonationPresenter.format_idr(-1) == "-1"
      assert DonationPresenter.format_idr(-10_000) == "-10.000"
    end
  end

  describe "present_message?/1" do
    test "returns true only for non-empty strings" do
      assert DonationPresenter.present_message?("hello")
      assert DonationPresenter.present_message?(" hello ")
      refute DonationPresenter.present_message?("")
      refute DonationPresenter.present_message?("   ")
      refute DonationPresenter.present_message?(nil)
    end
  end
end
