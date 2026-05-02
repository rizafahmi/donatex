defmodule DonatexWeb.DonateLive do
  use DonatexWeb, :live_view

  import Ecto.Changeset

  @preset_amounts [5_000, 10_000, 25_000]
  @preset_amount_options Enum.map(@preset_amounts, &Integer.to_string/1)
  @form_fields [:donor_name, :amount_option, :custom_amount, :message]
  @form_types %{
    donor_name: :string,
    amount_option: :string,
    custom_amount: :integer,
    message: :string
  }

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    preset_amounts =
      Enum.map(@preset_amounts, fn amount ->
        option = Integer.to_string(amount)

        %{
          value: amount,
          option: option,
          id: amount_option_id(amount),
          formatted: format_idr(amount)
        }
      end)

    {:ok,
     socket
     |> assign(:preset_amounts, preset_amounts)
     |> assign_form(donation_form_changeset(%{}, validate_required?: false))}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"donation_form" => params}, socket) do
    changeset =
      params
      |> donation_form_changeset()
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("submit", %{"donation_form" => params}, socket) do
    changeset = donation_form_changeset(params)

    next_changeset =
      if changeset.valid? do
        changeset
      else
        Map.put(changeset, :action, :insert)
      end

    {:noreply, assign_form(socket, next_changeset)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <% selected_amount_option = selected_amount_option(@form) %>
      <% amount_option_error = amount_option_error(@form) %>

      <section class="relative isolate overflow-hidden rounded-[2rem] border border-base-300/70 bg-base-100 px-6 py-8 shadow-sm sm:px-8">
        <div class="absolute inset-x-0 top-0 h-24 bg-linear-to-r from-primary/16 via-transparent to-secondary/12" />
        <div class="absolute -right-16 bottom-0 h-32 w-32 rounded-full bg-primary/10 blur-2xl" />

        <div class="relative space-y-4">
          <p class="text-xs font-semibold uppercase tracking-[0.3em] text-base-content/55">
            Support the stream
          </p>
          <div class="space-y-3">
            <h1 class="text-4xl font-semibold tracking-tight text-balance text-base-content sm:text-5xl">
              Donate
            </h1>
            <p class="max-w-xl text-sm leading-6 text-base-content/70 sm:text-base">
              Send a quick QRIS tip from your phone. Your alert appears on stream after payment
              confirmation lands.
            </p>
          </div>

          <div class="grid gap-3 pt-2 sm:grid-cols-3">
            <div class="rounded-2xl border border-base-300/80 bg-base-200/70 px-4 py-3">
              <p class="text-xs font-semibold uppercase tracking-[0.22em] text-base-content/55">
                Mobile ready
              </p>
              <p class="mt-2 text-sm text-base-content/75">
                Fast form, large tap targets, no account needed.
              </p>
            </div>
            <div class="rounded-2xl border border-base-300/80 bg-base-200/70 px-4 py-3">
              <p class="text-xs font-semibold uppercase tracking-[0.22em] text-base-content/55">
                QRIS only
              </p>
              <p class="mt-2 text-sm text-base-content/75">
                Pay with any QRIS-compatible banking or wallet app.
              </p>
            </div>
            <div class="rounded-2xl border border-base-300/80 bg-base-200/70 px-4 py-3">
              <p class="text-xs font-semibold uppercase tracking-[0.22em] text-base-content/55">
                Live alert
              </p>
              <p class="mt-2 text-sm text-base-content/75">
                Name, amount, and message show after Mayar confirms payment.
              </p>
            </div>
          </div>
        </div>
      </section>

      <section class="rounded-[2rem] border border-base-300/70 bg-base-100 px-6 py-6 shadow-sm sm:px-8 sm:py-8">
        <.form
          for={@form}
          id="donation-form"
          phx-change="validate"
          phx-submit="submit"
          class="space-y-6"
        >
          <div class="space-y-2">
            <p class="text-sm font-medium text-base-content/80">
              Fill in your name, pick an amount, and add a message if you want one on stream.
            </p>
            <div class="h-px bg-base-300/80" />
          </div>

          <.input
            field={@form[:donor_name]}
            label="Your name"
            placeholder="Riza"
            autocomplete="name"
            required
          />

          <fieldset class="space-y-3">
            <legend class="w-full">
              <span class="flex items-center justify-between gap-3">
                <span class="text-sm font-semibold text-base-content">Choose an amount</span>
                <span class="text-xs uppercase tracking-[0.2em] text-base-content/50">IDR</span>
              </span>
            </legend>

            <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
              <label
                :for={preset <- @preset_amounts}
                for={preset.id}
                class={amount_option_classes(selected_amount_option == preset.option)}
              >
                <input
                  id={preset.id}
                  type="radio"
                  name={@form[:amount_option].name}
                  value={preset.value}
                  checked={selected_amount_option == preset.option}
                  class="sr-only"
                />
                <span class="text-base font-semibold text-base-content">Rp {preset.formatted}</span>
                <span class="text-xs text-base-content/60">Quick tap</span>
              </label>

              <label
                for="donation_form_amount_option_custom"
                class={amount_option_classes(selected_amount_option == "custom")}
              >
                <input
                  id="donation_form_amount_option_custom"
                  type="radio"
                  name={@form[:amount_option].name}
                  value="custom"
                  checked={selected_amount_option == "custom"}
                  class="sr-only"
                />
                <span class="text-base font-semibold text-base-content">Custom</span>
                <span class="text-xs text-base-content/60">Set your own</span>
              </label>
            </div>

            <p :if={amount_option_error} class="text-sm font-medium text-error">
              {amount_option_error}
            </p>
          </fieldset>

          <div
            :if={selected_amount_option == "custom"}
            class="rounded-2xl border border-base-300/80 bg-base-200/50 px-4 py-4"
          >
            <.input
              field={@form[:custom_amount]}
              type="number"
              label="Custom amount"
              placeholder="15000"
              min="1"
              step="1000"
              required
            />
            <p class="text-xs text-base-content/60">
              Enter the amount in rupiah, without dots or commas.
            </p>
          </div>

          <.input
            field={@form[:message]}
            type="textarea"
            label="Message (optional)"
            rows="4"
            maxlength="160"
            placeholder="Say something kind, funny, or hype for the stream."
          />

          <div class="space-y-3 pt-2">
            <button
              type="submit"
              class="inline-flex w-full items-center justify-between rounded-2xl bg-primary px-5 py-4 text-left text-sm font-semibold text-primary-content transition hover:opacity-95 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
            >
              <span>Create your QRIS</span>
              <span aria-hidden="true">&rarr;</span>
            </button>

            <p class="text-xs leading-5 text-base-content/60">
              You will review the QR code on the next step before paying.
            </p>
          </div>
        </.form>
      </section>
    </Layouts.app>
    """
  end

  defp donation_form_changeset(params, opts \\ []) do
    validate_required? = Keyword.get(opts, :validate_required?, true)

    {%{}, @form_types}
    |> cast(params, @form_fields)
    |> update_change(:donor_name, &trim/1)
    |> maybe_validate_required(validate_required?)
  end

  defp maybe_validate_required(changeset, false), do: changeset

  defp maybe_validate_required(changeset, true) do
    changeset
    |> validate_required([:donor_name], message: "Please enter your name")
    |> validate_length(:donor_name, max: 40, message: "Name must be at most 40 characters")
    |> validate_amount()
    |> validate_length(:message, max: 160, message: "Message must be at most 160 characters")
  end

  defp validate_amount(changeset) do
    case get_field(changeset, :amount_option) do
      option when option in @preset_amount_options ->
        changeset

      "custom" ->
        changeset
        |> validate_required([:custom_amount], message: "Enter your donation amount")
        |> validate_number(:custom_amount,
          greater_than: 0,
          message: "Enter a donation amount greater than zero"
        )

      _ ->
        add_error(changeset, :amount_option, "Choose a donation amount")
    end
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: :donation_form))
  end

  defp selected_amount_option(form), do: form[:amount_option].value

  defp amount_option_error(form) do
    case form[:amount_option].errors do
      [{message, _opts} | _rest] -> message
      _ -> nil
    end
  end

  defp amount_option_id(amount), do: "donation_form_amount_option_#{amount}"

  defp amount_option_classes(true) do
    [
      "flex min-h-28 cursor-pointer flex-col justify-between rounded-2xl border px-4 py-4 transition",
      "border-primary bg-primary/10 shadow-sm"
    ]
  end

  defp amount_option_classes(false) do
    [
      "flex min-h-28 cursor-pointer flex-col justify-between rounded-2xl border px-4 py-4 transition",
      "border-base-300 bg-base-200/60 hover:border-primary/50 hover:bg-base-200"
    ]
  end

  defp format_idr(amount) do
    amount
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&(Enum.reverse(&1) |> Enum.join()))
    |> Enum.reverse()
    |> Enum.join(".")
  end

  defp trim(value) when is_binary(value), do: String.trim(value)
  defp trim(value), do: value
end
