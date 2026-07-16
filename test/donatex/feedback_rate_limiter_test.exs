defmodule Donatex.FeedbackRateLimiterTest do
  use ExUnit.Case, async: false

  alias Donatex.FeedbackRateLimiter

  setup do
    FeedbackRateLimiter.reset()
    :ok
  end

  test "rejects a second free feedback from the same IP within 10 seconds" do
    ip = {127, 0, 0, 1}

    assert :ok = FeedbackRateLimiter.check(ip)
    assert {:error, :rate_limited} = FeedbackRateLimiter.check(ip)
  end

  test "allows free feedback again after the cooldown elapses" do
    ip = {10, 0, 0, 1}

    assert :ok = FeedbackRateLimiter.check(ip, now: 0)
    assert {:error, :rate_limited} = FeedbackRateLimiter.check(ip, now: 5_000)
    assert :ok = FeedbackRateLimiter.check(ip, now: 10_000)
  end
end
