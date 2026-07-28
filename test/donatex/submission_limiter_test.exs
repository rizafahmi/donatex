defmodule Donatex.SubmissionLimiterTest do
  use ExUnit.Case, async: false

  alias Donatex.SubmissionLimiter

  setup do
    SubmissionLimiter.reset()
    :ok
  end

  test "rejects a second submission for the same key within 10 seconds" do
    key = {:feedback, {127, 0, 0, 1}}

    assert :ok = SubmissionLimiter.reserve(key)
    assert {:error, :rate_limited} = SubmissionLimiter.reserve(key)
  end

  test "allows another submission after the cooldown elapses" do
    key = {:feedback, {10, 0, 0, 1}}

    assert :ok = SubmissionLimiter.reserve(key, now: 0)
    assert {:error, :rate_limited} = SubmissionLimiter.reserve(key, now: 5_000)
    assert :ok = SubmissionLimiter.reserve(key, now: 10_000)
  end

  test "release clears the reservation so another reserve can succeed" do
    key = {:feedback, {10, 0, 0, 2}}

    assert :ok = SubmissionLimiter.reserve(key)
    assert :ok = SubmissionLimiter.release(key)
    assert :ok = SubmissionLimiter.reserve(key)
  end

  test "namespaced keys are independent across consumers" do
    visitor = "visitor-1"
    ip = {10, 0, 0, 3}

    assert :ok = SubmissionLimiter.reserve({:question, visitor})
    # A question submission does not consume the feedback/tip cooldown and vice versa.
    assert :ok = SubmissionLimiter.reserve({:feedback, ip})
    assert :ok = SubmissionLimiter.reserve({:tip, ip})

    assert {:error, :rate_limited} = SubmissionLimiter.reserve({:question, visitor})
    assert {:error, :rate_limited} = SubmissionLimiter.reserve({:feedback, ip})
    assert {:error, :rate_limited} = SubmissionLimiter.reserve({:tip, ip})
  end
end
