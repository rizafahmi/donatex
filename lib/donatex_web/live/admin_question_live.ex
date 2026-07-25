defmodule DonatexWeb.AdminQuestionLive do
  use DonatexWeb, :live_view

  alias Donatex.Questions

  @pubsub Donatex.PubSub
  @topic "questions"

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(@pubsub, @topic)
    end

    socket =
      socket
      |> assign(:page_title, "Moderasi Pertanyaan · Admin")
      |> assign(
        :meta_description,
        "Moderasi pertanyaan audiens: tandai terjawab, sembunyikan, dan kembalikan."
      )
      |> assign(:meta_robots, "noindex, nofollow")
      |> assign(:canonical_url, canonical_url("/admin/questions"))
      |> assign(:expanded_dates, %{})
      |> load_summaries()

    {:ok, socket}
  end

  ## Events

  @impl Phoenix.LiveView
  def handle_event("toggle_date", %{"date" => date_str}, socket) do
    {:ok, date} = Date.from_iso8601(date_str)

    if Map.has_key?(socket.assigns.expanded_dates, date) do
      {:noreply, assign(socket, :expanded_dates, Map.delete(socket.assigns.expanded_dates, date))}
    else
      rows = Questions.list_questions_for_date(date, include_hidden: true)

      {:noreply,
       assign(socket, :expanded_dates, Map.put(socket.assigns.expanded_dates, date, rows))}
    end
  end

  def handle_event("mark_answered", %{"id" => id}, socket) do
    case Questions.mark_answered(id) do
      {:ok, _} -> {:noreply, reload_visible(socket, id)}
      {:error, :not_found} -> {:noreply, put_flash(socket, :error, "Pertanyaan tidak ditemukan.")}
    end
  end

  def handle_event("reopen", %{"id" => id}, socket) do
    case Questions.reopen(id) do
      {:ok, _} -> {:noreply, reload_visible(socket, id)}
      {:error, :not_found} -> {:noreply, put_flash(socket, :error, "Pertanyaan tidak ditemukan.")}
    end
  end

  def handle_event("hide", %{"id" => id}, socket) do
    case Questions.hide(id) do
      {:ok, _} -> {:noreply, reload_visible(socket, id)}
      {:error, :not_found} -> {:noreply, put_flash(socket, :error, "Pertanyaan tidak ditemukan.")}
    end
  end

  def handle_event("restore", %{"id" => id}, socket) do
    case Questions.restore(id) do
      {:ok, _} -> {:noreply, reload_visible(socket, id)}
      {:error, :not_found} -> {:noreply, put_flash(socket, :error, "Pertanyaan tidak ditemukan.")}
    end
  end

  ## PubSub

  @impl Phoenix.LiveView
  def handle_info({:question_created, id}, socket) do
    case Questions.get_question(id) do
      nil ->
        {:noreply, socket}

      q ->
        {:noreply,
         socket
         |> load_summaries()
         |> reload_date(Questions.wib_date_of_utc_datetime(q.inserted_at))}
    end
  end

  def handle_info({:question_changed, id}, socket) do
    case Questions.get_question(id) do
      nil ->
        {:noreply, socket}

      q ->
        {:noreply,
         socket
         |> load_summaries()
         |> reload_date(Questions.wib_date_of_utc_datetime(q.inserted_at))}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  ## Rendering

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section id="admin-questions" class="space-y-6">
        <header class="space-y-2">
          <div class="flex items-center justify-between gap-3">
            <h1
              id="admin-questions-heading"
              class="font-display text-3xl font-semibold tracking-tight text-text sm:text-4xl"
            >
              Moderasi Pertanyaan
            </h1>
            <.link
              navigate={~p"/admin"}
              class="rounded-full border border-stroke/60 bg-surface/60 px-3 py-1.5 text-xs font-semibold text-text-muted transition hover:border-stroke hover:text-text"
            >
              Ke Admin
            </.link>
          </div>
          <p class="max-w-2xl text-sm leading-6 text-text-muted">
            Tandai pertanyaan terjawab, buka kembali, sembunyikan, atau kembalikan. Pertanyaan tersembunyi tetap mempertahankan status terjawab.
          </p>
        </header>

        <.admin_date_groups
          summaries={@date_summaries}
          expanded_dates={@expanded_dates}
        />
      </section>
    </Layouts.app>
    """
  end

  attr :summaries, :list, required: true
  attr :expanded_dates, :map, required: true

  defp admin_date_groups(assigns) do
    ~H"""
    <section id="admin-date-board" class="space-y-3">
      <p
        :if={@summaries == []}
        id="admin-questions-empty"
        class="rounded-2xl border border-stroke/60 bg-background/12 px-4 py-6 text-center text-sm text-text-muted"
      >
        Belum ada pertanyaan.
      </p>

      <.admin_date_group
        :for={summary <- @summaries}
        summary={summary}
        expanded?={Map.has_key?(@expanded_dates, summary.wib_date)}
        rows={@expanded_dates[summary.wib_date]}
      />
    </section>
    """
  end

  attr :summary, :map, required: true
  attr :expanded?, :boolean, required: true
  attr :rows, :list, default: nil

  defp admin_date_group(assigns) do
    ~H"""
    <div
      id={"admin-date-group-#{@summary.wib_date}"}
      class="rounded-2xl border border-stroke/60 bg-background/12"
    >
      <button
        type="button"
        class="flex w-full items-center justify-between px-4 py-3 text-left"
        phx-click="toggle_date"
        phx-value-date={@summary.wib_date}
        aria-expanded={if @expanded?, do: "true", else: "false"}
        aria-controls={"admin-date-list-#{@summary.wib_date}"}
      >
        <span class="text-sm font-medium text-text">
          {Calendar.strftime(@summary.wib_date, "%d %b %Y")}
        </span>
        <span class="text-xs text-text-muted">
          {@summary.total} pertanyaan · {@summary.open} terbuka
        </span>
      </button>

      <div
        :if={@expanded?}
        id={"admin-date-list-#{@summary.wib_date}"}
        class="border-t border-stroke/50 px-2 pb-2 pt-3"
      >
        <ul :if={@rows != nil and @rows != []} class="space-y-2" role="list">
          <.admin_question_row :for={row <- @rows} row={row} />
        </ul>
        <p :if={@rows == nil} class="py-4 text-center text-sm text-text-muted">Memuat…</p>
        <p :if={@rows == []} class="py-4 text-center text-sm text-text-muted">
          Tidak ada pertanyaan.
        </p>
      </div>
    </div>
    """
  end

  attr :row, :map, required: true

  defp admin_question_row(assigns) do
    assigns =
      assigns
      |> assign(:answered?, assigns.row.question.status == "answered")
      |> assign(:hidden?, assigns.row.question.hidden_at != nil)
      |> assign(:id, assigns.row.question.id)

    ~H"""
    <li
      id={"admin-question-#{@id}"}
      class="rounded-2xl border border-stroke/60 bg-surface/45 px-4 py-3"
    >
      <div class="space-y-2">
        <div class="flex items-start justify-between gap-3">
          <div class="min-w-0 flex-1 space-y-1">
            <p class="text-sm font-semibold text-text">{display_name(@row.question.name)}</p>
            <p class="break-words text-sm leading-6 text-text">{@row.question.body}</p>
          </div>
          <div class="flex shrink-0 flex-col items-end gap-1 text-xs text-text-muted">
            <span>{wib_timestamp(@row.question.inserted_at)}</span>
            <span class="rounded-full bg-accent/15 px-2 py-0.5 font-semibold text-accent">
              {@row.vote_count} upvote
            </span>
          </div>
        </div>

        <div class="flex flex-wrap items-center gap-2">
          <span class={[
            "rounded-full px-2 py-0.5 text-[0.65rem] font-semibold",
            if(@answered?,
              do: "bg-accent-2/15 text-accent-2",
              else: "bg-accent/15 text-accent"
            )
          ]}>
            {if @answered?, do: "Terjawab", else: "Terbuka"}
          </span>
          <span class={[
            "rounded-full px-2 py-0.5 text-[0.65rem] font-semibold",
            if(@hidden?,
              do: "bg-danger/15 text-danger",
              else: "bg-stroke/40 text-text-muted"
            )
          ]}>
            {if @hidden?, do: "Tersembunyi", else: "Tampil"}
          </span>

          <div class="ml-auto flex flex-wrap gap-2">
            <.button
              :if={not @answered?}
              type="button"
              phx-click="mark_answered"
              phx-value-id={@id}
              variant="ghost"
              class="text-xs"
            >
              Tandai terjawab
            </.button>
            <.button
              :if={@answered?}
              type="button"
              phx-click="reopen"
              phx-value-id={@id}
              variant="ghost"
              class="text-xs"
            >
              Buka kembali
            </.button>
            <.button
              :if={not @hidden?}
              type="button"
              phx-click="hide"
              phx-value-id={@id}
              variant="ghost"
              class="text-xs"
            >
              Sembunyikan
            </.button>
            <.button
              :if={@hidden?}
              type="button"
              phx-click="restore"
              phx-value-id={@id}
              variant="ghost"
              class="text-xs"
            >
              Kembalikan
            </.button>
          </div>
        </div>
      </div>
    </li>
    """
  end

  ## Helpers

  defp load_summaries(socket) do
    assign(socket, :date_summaries, Questions.list_date_summaries(include_hidden: true))
  end

  defp reload_expanded(socket, date) do
    rows = Questions.list_questions_for_date(date, include_hidden: true)
    assign(socket, :expanded_dates, Map.put(socket.assigns.expanded_dates, date, rows))
  end

  defp reload_date(socket, date) do
    if Map.has_key?(socket.assigns.expanded_dates, date) do
      reload_expanded(socket, date)
    else
      socket
    end
  end

  defp reload_visible(socket, question_id) do
    case Questions.get_question(question_id) do
      nil ->
        socket

      question ->
        socket
        |> load_summaries()
        |> reload_date(Questions.wib_date_of_utc_datetime(question.inserted_at))
    end
  end

  defp display_name(nil), do: "Anonim"
  defp display_name(name) when is_binary(name), do: name

  defp wib_timestamp(utc_datetime) do
    wib = DateTime.add(utc_datetime, 7 * 3600, :second)
    Calendar.strftime(wib, "%d %b %H:%M WIB")
  end

  defp canonical_url(path) do
    base =
      Application.get_env(:donatex, :app)[:base_url] |> to_string() |> String.trim_trailing("/")

    base <> path
  end
end
