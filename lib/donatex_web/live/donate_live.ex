defmodule DonatexWeb.DonateLive do
  use DonatexWeb, :live_view

  import Ecto.Changeset

  require Logger

  alias Donatex.Donations
  alias Donatex.Mayar.Client
  alias DonatexWeb.DonationPresenter

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
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Donatex.PubSub, "donations:paid")
    end

    preset_amounts =
      Enum.map(@preset_amounts, fn amount ->
        option = Integer.to_string(amount)

        %{
          value: amount,
          option: option,
          id: amount_option_id(amount),
          formatted: DonationPresenter.format_idr(amount)
        }
      end)

    {:ok,
     socket
     |> assign(:preset_amounts, preset_amounts)
     |> assign(:step, :form)
     |> assign(:donation, nil)
     |> assign(:qr, nil)
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

    if changeset.valid? do
      case create_pending_donation_with_qr(changeset) do
        {:ok, donation, qr} ->
          {:noreply,
           socket
           |> assign(:step, :payment)
           |> assign(:donation, donation)
           |> assign(:qr, qr)
           |> maybe_reconcile_paid_donation()}

        {:error, :mayar, reason} ->
          {:noreply,
           socket
           |> put_flash(:error, qr_error_message(reason))
           |> assign_form(changeset)}

        {:error, :donation, _donation_changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, donation_persist_error_message())
           |> assign_form(changeset)}
      end
    else
      {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  def handle_event("new_donation", _params, socket) do
    {:noreply,
     socket
     |> assign(:step, :form)
     |> assign(:donation, nil)
     |> assign(:qr, nil)
     |> assign_form(donation_form_changeset(%{}, validate_required?: false))}
  end

  @impl Phoenix.LiveView
  def handle_info({:donation_paid, payload}, socket) when is_map(payload) do
    if donation_match?(socket.assigns[:donation], payload) do
      {:noreply, assign(socket, :step, :paid)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <%= if @step == :payment do %>
        <section class="rounded-[2rem] border border-stroke/60 bg-surface/55 px-6 py-8 shadow-lg shadow-black/25 sm:px-8">
          <div class="space-y-3">
            <p class="text-xs font-semibold uppercase tracking-[0.3em] text-text-muted">
              Almost there
            </p>
            <h1 class="font-display text-3xl font-semibold tracking-tight text-balance text-text sm:text-4xl">
              Scan the QRIS
            </h1>
            <p class="max-w-xl text-sm leading-6 text-text-muted sm:text-base">
              Open your banking or wallet app and scan the code. This page will update when the payment is confirmed.
            </p>
          </div>

          <div class="mt-8 grid gap-6 sm:grid-cols-2 sm:items-start">
            <div class="rounded-2xl border border-stroke/60 bg-background/35 p-6">
              <img
                src={@qr.qr_image_url}
                alt="QRIS QR code"
                class="mx-auto w-full max-w-xs rounded-xl bg-surface/60 p-4 shadow-sm shadow-black/30"
              />
            </div>

            <div class="space-y-4">
              <div class="rounded-2xl border border-stroke/60 bg-background/35 px-5 py-4">
                <p class="text-xs font-semibold uppercase tracking-[0.22em] text-text-muted">
                  Donation
                </p>
                <p class="mt-2 text-lg font-semibold text-text">
                  Rp {DonationPresenter.format_idr(@donation.amount)}
                </p>
                <p class="mt-2 text-sm text-text-muted">
                  From {@donation.donor_name}
                </p>
                <p
                  :if={DonationPresenter.present_message?(@donation.message)}
                  class="mt-3 text-sm text-text-muted"
                >
                  "{@donation.message}"
                </p>
              </div>
            </div>
          </div>
        </section>
      <% else %>
        <%= if @step == :paid do %>
          <section class="rounded-[2rem] border border-stroke/60 bg-surface/55 px-6 py-8 shadow-lg shadow-black/25 sm:px-8">
            <div class="space-y-3">
              <p class="text-xs font-semibold uppercase tracking-[0.3em] text-success">
                Payment confirmed
              </p>
              <h1 class="font-display text-3xl font-semibold tracking-tight text-balance text-text sm:text-4xl">
                Thank you for the support
              </h1>
              <p class="max-w-xl text-sm leading-6 text-text-muted sm:text-base">
                Your donation is paid and will show on stream.
              </p>
            </div>

            <div class="mt-8 rounded-2xl border border-stroke/60 bg-background/35 px-5 py-4">
              <p class="text-xs font-semibold uppercase tracking-[0.22em] text-text-muted">
                Donation
              </p>
              <p class="mt-2 text-lg font-semibold text-text">
                Rp {DonationPresenter.format_idr(@donation.amount)}
              </p>
              <p class="mt-2 text-sm text-text-muted">From {@donation.donor_name}</p>
              <p
                :if={DonationPresenter.present_message?(@donation.message)}
                class="mt-3 text-sm text-text-muted"
              >
                "{@donation.message}"
              </p>
            </div>

            <div class="mt-6">
              <.button type="button" phx-click="new_donation">
                Make another donation
              </.button>
            </div>
          </section>
        <% else %>
          <% selected_amount_option = selected_amount_option(@form) %>
          <% amount_option_error = amount_option_error(@form) %>

          <section class="relative isolate overflow-hidden rounded-[2rem] border border-stroke/60 bg-surface/55 px-6 py-8 shadow-lg shadow-black/25 sm:px-8">
            <div class="absolute inset-x-0 top-0 h-24 bg-linear-to-r from-accent/14 via-transparent to-accent-2/12" />
            <div class="absolute -right-16 bottom-0 h-32 w-32 rounded-full bg-accent/10 blur-2xl" />

            <div class="relative space-y-4">
              <p class="text-xs font-semibold uppercase tracking-[0.3em] text-text-muted">
                Support the stream
              </p>
              <div class="space-y-3">
                <h1 class="font-display text-4xl font-semibold tracking-tight text-balance text-text sm:text-5xl">
                  Donate
                </h1>
                <p class="max-w-xl text-sm leading-6 text-text-muted sm:text-base">
                  Send a quick QRIS tip from your phone. Your alert appears on stream after payment
                  confirmation lands.
                </p>
              </div>

              <div class="grid gap-3 pt-2 sm:grid-cols-3">
                <div class="rounded-2xl border border-stroke/60 bg-background/35 px-4 py-3">
                  <p class="text-xs font-semibold uppercase tracking-[0.22em] text-text-muted">
                    Mobile ready
                  </p>
                  <p class="mt-2 text-sm text-text-muted">
                    Fast form, large tap targets, no account needed.
                  </p>
                </div>
                <div class="rounded-2xl border border-stroke/60 bg-background/35 px-4 py-3">
                  <p class="text-xs font-semibold uppercase tracking-[0.22em] text-text-muted">
                    QRIS only
                  </p>
                  <p class="mt-2 text-sm text-text-muted">
                    Pay with any QRIS-compatible banking or wallet app.
                  </p>
                </div>
                <div class="rounded-2xl border border-stroke/60 bg-background/35 px-4 py-3">
                  <p class="text-xs font-semibold uppercase tracking-[0.22em] text-text-muted">
                    Live alert
                  </p>
                  <p class="mt-2 text-sm text-text-muted">
                    Name, amount, and message show after Mayar confirms payment.
                  </p>
                </div>
              </div>
            </div>
          </section>

          <section class="rounded-[2rem] border border-stroke/60 bg-surface/55 px-6 py-6 shadow-lg shadow-black/25 sm:px-8 sm:py-8">
            <.form
              for={@form}
              id="donation-form"
              phx-change="validate"
              phx-submit="submit"
              class="space-y-6"
            >
              <div class="space-y-2">
                <p class="text-sm font-medium text-text-muted">
                  Fill in your name, pick an amount, and add a message if you want one on stream.
                </p>
                <div class="h-px bg-stroke/60" />
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
                    <span class="text-sm font-semibold text-text">Choose an amount</span>
                    <span class="text-xs uppercase tracking-[0.2em] text-text-muted">IDR</span>
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
                    <span class="text-base font-semibold text-text">
                      Rp {preset.formatted}
                    </span>
                    <span class="text-xs text-text-muted">Quick tap</span>
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
                    <span class="text-base font-semibold text-text">Custom</span>
                    <span class="text-xs text-text-muted">Set your own</span>
                  </label>
                </div>

                <p :if={amount_option_error} class="text-sm font-medium text-danger">
                  {amount_option_error}
                </p>
              </fieldset>

              <div
                :if={selected_amount_option == "custom"}
                class="rounded-2xl border border-stroke/60 bg-background/35 px-4 py-4"
              >
                <.input
                  field={@form[:custom_amount]}
                  type="number"
                  label="Custom amount"
                  placeholder="15000"
                  min="1000"
                  step="1000"
                  required
                />
                <p class="text-xs text-text-muted">
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
                  class="inline-flex w-full items-center justify-between rounded-2xl bg-accent px-5 py-4 text-left text-sm font-semibold text-background shadow-sm shadow-accent/20 ring-1 ring-accent/30 transition hover:bg-accent/92 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
                >
                  <span>Create your QRIS</span>
                  <span aria-hidden="true">&rarr;</span>
                </button>

                <p class="text-xs leading-5 text-text-muted">
                  You will review the QR code on the next step before paying.
                </p>
              </div>
            </.form>
          </section>
        <% end %>
      <% end %>
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
          greater_than_or_equal_to: 1_000,
          message: "Enter a donation amount of at least 1000"
        )
        |> validate_change(:custom_amount, fn :custom_amount, amount ->
          validate_custom_amount_step(amount)
        end)

      _ ->
        add_error(changeset, :amount_option, "Choose a donation amount")
    end
  end

  defp validate_custom_amount_step(amount)
       when is_integer(amount) and rem(amount, 1_000) == 0,
       do: []

  defp validate_custom_amount_step(_amount),
    do: [custom_amount: "Enter an amount in multiples of 1000"]

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
      "border-accent/50 bg-accent/10 shadow-sm shadow-black/30"
    ]
  end

  defp amount_option_classes(false) do
    [
      "flex min-h-28 cursor-pointer flex-col justify-between rounded-2xl border px-4 py-4 transition",
      "border-stroke/60 bg-background/25 hover:border-stroke hover:bg-background/35"
    ]
  end

  defp trim(value) when is_binary(value), do: String.trim(value)
  defp trim(value), do: value

  defp create_pending_donation_with_qr(changeset) do
    donor_name = get_field(changeset, :donor_name)
    amount = donation_amount(changeset)
    message = blank_to_nil(get_field(changeset, :message))

    with {:ok, %Client.DynamicQr{} = qr} <- Client.create_qr(amount),
         {:ok, donation} <-
           create_pending_donation_from_qr(qr, %{
             donor_name: donor_name,
             amount: amount,
             message: message
           }) do
      {:ok, donation, qr}
    else
      {:error, %Ecto.Changeset{} = donation_changeset, %Client.DynamicQr{} = qr} ->
        log_failed_donation_persist(qr, amount, donation_changeset)
        {:error, :donation, donation_changeset}

      {:error, reason} ->
        {:error, :mayar, reason}
    end
  end

  defp create_pending_donation_from_qr(%Client.DynamicQr{} = qr, %{
         donor_name: donor_name,
         amount: amount,
         message: message
       }) do
    case Donations.create_pending_donation(%{
           mayar_transaction_id: qr.mayar_transaction_id,
           donor_name: donor_name,
           amount: amount,
           message: message
         }) do
      {:ok, donation} -> {:ok, donation}
      {:error, %Ecto.Changeset{} = donation_changeset} -> {:error, donation_changeset, qr}
    end
  end

  defp donation_amount(changeset) do
    case get_field(changeset, :amount_option) do
      option when option in @preset_amount_options -> String.to_integer(option)
      "custom" -> get_field(changeset, :custom_amount)
    end
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  defp maybe_reconcile_paid_donation(%{assigns: %{step: :payment, donation: %{id: id}}} = socket) do
    case Donations.get_donation(id) do
      %{status: "paid"} -> assign(socket, :step, :paid)
      _ -> socket
    end
  end

  defp maybe_reconcile_paid_donation(socket), do: socket

  defp donation_match?(%{id: id}, %{id: payload_id}) when is_binary(id) and is_binary(payload_id),
    do: id == payload_id

  defp donation_match?(%{mayar_transaction_id: tx}, %{mayar_transaction_id: payload_tx})
       when is_binary(tx) and is_binary(payload_tx),
       do: tx == payload_tx

  defp donation_match?(_donation, _payload), do: false

  defp qr_error_message(reason) do
    base_message = "Could not create a QR right now. Please try again."

    if show_mayar_error_reason?() do
      "#{base_message} (#{mayar_reason(reason)})"
    else
      base_message
    end
  end

  defp show_mayar_error_reason? do
    Application.get_env(:donatex, :show_mayar_error_reason, false)
  end

  defp mayar_reason({:unexpected_response, _body}), do: "unexpected_response"
  defp mayar_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp mayar_reason(reason), do: inspect(reason)

  defp changeset_error_summary(%Ecto.Changeset{errors: errors}) when is_list(errors) do
    Enum.map(errors, fn
      {field, {message, _opts}} -> {field, message}
      other -> other
    end)
  end

  defp donation_persist_error_message do
    "Could not save your donation. Please try again. If you already scanned a QR code, please do not complete payment."
  end

  defp log_failed_donation_persist(%Client.DynamicQr{} = qr, amount, donation_changeset) do
    Logger.warning(
      "Could not persist pending donation mayar_transaction_id=#{qr.mayar_transaction_id} amount=#{amount} errors=#{inspect(changeset_error_summary(donation_changeset))}"
    )
  end
end
