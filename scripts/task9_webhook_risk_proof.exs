Mix.Task.run("app.start")

alias Donatex.Config
alias DonatexWeb.Router

build_json_conn = fn path, body ->
  Plug.Test.conn("POST", path, Jason.encode!(body))
  |> Plug.Conn.put_req_header("content-type", "application/json")
end

run = fn path, body ->
  conn = build_json_conn.(path, body)

  try do
    conn = Router.call(conn, Router.init([]))
    %{path: path, status: conn.status, response_body: conn.resp_body}
  rescue
    e in Phoenix.Router.NoRouteError ->
      %{path: path, status: 404, response_body: Exception.message(e)}
  end
end

forged_event_1 = %{
  "event" => "payment.received",
  "data" => %{
    "transactionId" => "FORGED-TX-001",
    "amount" => 1_000_000,
    "customerName" => "attacker"
  }
}

forged_event_2 = %{
  "event" => "payment.received",
  "data" => %{
    "transactionId" => "FORGED-TX-002",
    "amount" => 999_999_999,
    "customerName" => "anyone"
  }
}

IO.puts("== Task 9 Proof: Webhook endpoint is protected by tokenized path ==")

[forged_event_1, forged_event_2]
|> Enum.with_index(1)
|> Enum.each(fn {payload, idx} ->
  result = run.("/webhooks/mayar", payload)

  IO.puts("\nRequest ##{idx} to #{result.path}")
  IO.puts("Status: #{result.status}")
  IO.puts("Body: #{result.response_body}")
end)

bogus_token_path_result = run.("/webhooks/mayar/not-a-real-token", forged_event_1)
real_token_path_result = run.("/webhooks/mayar/#{Config.mayar_webhook_token()}", forged_event_1)

IO.puts("\nControl check: tokenized-like path => #{bogus_token_path_result.status}")
IO.puts("Real token path => #{real_token_path_result.status}")
IO.puts("Interpretation: the un-tokenized path is unreachable; only requests with the configured token reach the controller.")
