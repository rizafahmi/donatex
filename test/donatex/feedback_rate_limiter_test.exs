defmodule Donatex.FeedbackRateLimiterTest do
  use ExUnit.Case, async: false

  alias Donatex.FeedbackRateLimiter

  test "rejects a second free feedback from the same IP within 10 seconds" do
    ip = {127, 0, 0, 1}

    assert :ok = FeedbackRateLimiter.check(ip)
    assert {:error, :rate_limited} = FeedbackRateLimiter.check(ip)
  end
end
