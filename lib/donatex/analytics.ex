defmodule Donatex.Analytics do
  @moduledoc """
  The analytics context.
  """

  import Ecto.Query, warn: false
  alias Donatex.Analytics.PageView
  alias Donatex.Donations.Donation
  alias Donatex.Repo

  @doc """
  Records a page view for the given path (asynchronously by default, or synchronously if configured).
  """
  def track_page_view(path) when is_binary(path) do
    if Application.get_env(:donatex, :async_analytics, true) do
      Task.start(fn -> record_page_view(path) end)
    else
      record_page_view(path)
      {:ok, self()}
    end
  end

  defp record_page_view(path) do
    %PageView{}
    |> PageView.changeset(%{path: path})
    |> Repo.insert()

    Phoenix.PubSub.broadcast(
      Donatex.PubSub,
      "analytics:page_view",
      {:page_view_recorded, path}
    )
  end

  @doc """
  Fetches aggregate metrics for the conversion funnel.
  """
  def get_funnel_stats do
    views = Repo.aggregate(PageView, :count)

    feedback =
      Donation
      |> where([d], d.status == "sent")
      |> Repo.aggregate(:count)

    paid =
      Donation
      |> where([d], d.status == "paid")
      |> Repo.aggregate(:count)

    %{
      views: views,
      feedback: feedback,
      paid: paid
    }
  end
end
