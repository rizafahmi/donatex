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
        {title, hint, recommended?} = preset_amount_copy(amount)

        %{
          value: amount,
          option: option,
          id: amount_option_id(amount),
          formatted: DonationPresenter.format_idr(amount),
          title: title,
          hint: hint,
          recommended?: recommended?
        }
      end)

    {:ok,
     socket
     |> assign(:preset_amounts, preset_amounts)
     |> assign(:step, :form)
     |> assign(:donation, nil)
     |> assign(:qr, nil)
     |> assign_form(
       donation_form_changeset(%{"amount_option" => "10000"}, validate_required?: false)
     )}
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
     |> assign_form(
       donation_form_changeset(%{"amount_option" => "10000"}, validate_required?: false)
     )}
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
    <Layouts.app flash={@flash} show_header={false}>
      <%= if @step == :payment do %>
        <section class="relative isolate overflow-hidden rounded-[2.5rem] border border-stroke/60 bg-surface/45 px-6 py-8 shadow-xl shadow-black/35 sm:px-8">
          <div class="absolute inset-0 bg-linear-to-br from-accent/12 via-transparent to-accent-2/10" />
          <div class="absolute -left-20 top-10 h-56 w-56 rounded-full bg-accent/10 blur-3xl" />
          <div class="absolute -right-24 bottom-0 h-64 w-64 rounded-full bg-accent-2/10 blur-3xl" />

          <div class="relative space-y-3">
            <p class="text-xs font-semibold uppercase tracking-[0.34em] text-text-muted">
              Tinggal sedikit lagi
            </p>
            <h1 class="font-display text-3xl font-semibold tracking-tight text-balance text-text sm:text-4xl">
              Scan QRIS-nya
            </h1>
            <p class="max-w-xl text-sm leading-6 text-text-muted sm:text-base">
              1) Buka aplikasi bank/e-wallet 2) Scan QRIS 3) Selesai—tunggu konfirmasi di halaman ini.
            </p>
            <div class="inline-flex items-center gap-2 rounded-full border border-stroke/60 bg-background/25 px-3 py-1.5 text-xs font-semibold text-text-muted">
              <span class="hero-arrow-path motion-safe:animate-spin"></span>
              Menunggu konfirmasi
              <span class="relative flex size-2 items-center justify-center">
                <span class="absolute inline-flex h-full w-full animate-ping rounded-full bg-accent opacity-75">
                </span>
                <span class="relative inline-flex size-1.5 rounded-full bg-accent"></span>
              </span>
            </div>
          </div>

          <div class="relative mt-8 grid gap-6 sm:grid-cols-2 sm:items-start">
            <div class="relative rounded-3xl border border-stroke/60 bg-background/30 p-6">
              <div class="absolute inset-3 rounded-2xl bg-linear-to-br from-accent/12 via-transparent to-accent-2/10 blur-xl" />
              <img
                src={@qr.qr_image_url}
                alt="Kode QRIS"
                class="relative mx-auto w-full max-w-xs rounded-2xl bg-surface/60 p-4 shadow-sm shadow-black/30 ring-1 ring-stroke/50 motion-safe:transition motion-safe:hover:scale-[1.01]"
              />
            </div>

            <div class="space-y-4">
              <div class="rounded-3xl border border-stroke/60 bg-background/25 px-5 py-5">
                <p class="text-xs font-semibold uppercase tracking-[0.24em] text-text-muted">
                  Ringkasan
                </p>
                <p class="mt-2 text-2xl font-semibold tracking-tight text-text">
                  Rp {DonationPresenter.format_idr(@donation.amount)}
                </p>
                <p class="mt-2 text-sm text-text-muted">
                  Dari {@donation.donor_name}
                </p>
                <p
                  :if={DonationPresenter.present_message?(@donation.message)}
                  class="mt-3 text-sm text-text-muted"
                >
                  "{@donation.message}"
                </p>
              </div>

              <div class="rounded-3xl border border-stroke/60 bg-background/15 px-5 py-5">
                <p class="text-sm font-semibold text-text">Tips biar lancar</p>
                <ul class="mt-3 space-y-2 text-sm text-text-muted">
                  <li class="flex items-start gap-2">
                    <span class="mt-0.5 size-1.5 rounded-full bg-accent/80"></span>
                    Jangan tutup halaman ini sampai status berubah.
                  </li>
                  <li class="flex items-start gap-2">
                    <span class="mt-0.5 size-1.5 rounded-full bg-accent-2/80"></span>
                    Bayar sekali saja untuk QR ini.
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </section>
      <% else %>
        <%= if @step == :paid do %>
          <section class="relative isolate overflow-hidden rounded-[2.5rem] border border-stroke/60 bg-surface/45 px-6 py-8 shadow-xl shadow-black/35 sm:px-8 transition-all duration-700 ease-out starting:scale-95 starting:opacity-0">
            <div class="absolute inset-0 bg-linear-to-br from-success/14 via-transparent to-accent/10" />
            <div class="absolute -left-16 top-8 h-56 w-56 rounded-full bg-success/10 blur-3xl" />
            <div class="absolute -right-20 bottom-0 h-64 w-64 rounded-full bg-accent/10 blur-3xl" />

            <div class="relative space-y-3">
              <p class="text-xs font-semibold uppercase tracking-[0.34em] text-success">
                Pembayaran terkonfirmasi
              </p>
              <h1 class="font-display text-3xl font-semibold tracking-tight text-balance text-text sm:text-4xl">
                Terima kasih! 🎉
              </h1>
              <p class="max-w-xl text-sm leading-6 text-text-muted sm:text-base">
                Donasimu sudah terkonfirmasi. Notifikasi akan tampil di stream.
              </p>
            </div>

            <div class="relative mt-8 rounded-3xl border border-stroke/60 bg-background/20 px-5 py-5">
              <p class="text-xs font-semibold uppercase tracking-[0.24em] text-text-muted">
                Ringkasan
              </p>
              <p class="mt-2 text-2xl font-semibold tracking-tight text-text">
                Rp {DonationPresenter.format_idr(@donation.amount)}
              </p>
              <p class="mt-2 text-sm text-text-muted">Dari {@donation.donor_name}</p>
              <p
                :if={DonationPresenter.present_message?(@donation.message)}
                class="mt-3 text-sm text-text-muted"
              >
                "{@donation.message}"
              </p>
            </div>

            <div class="relative mt-6 flex flex-wrap items-center gap-3">
              <.button type="button" phx-click="new_donation">
                Donasi lagi
              </.button>
              <.button navigate={~p"/"} variant="ghost">
                Kembali ke beranda
              </.button>
            </div>
          </section>
        <% else %>
          <% selected_amount_option = selected_amount_option(@form) %>
          <% amount_option_error = amount_option_error(@form) %>

          <section class="relative isolate overflow-hidden rounded-[2.75rem] border border-stroke/60 bg-surface/45 shadow-xl shadow-black/35">
            <div class="absolute inset-0 bg-linear-to-br from-accent/10 via-transparent to-accent-2/8" />
            <div class="absolute -right-32 top-24 h-72 w-72 rounded-full bg-accent/10 blur-3xl" />

            <div class="relative mx-auto max-w-3xl space-y-8 px-6 py-8 sm:px-8 lg:px-10 lg:py-10">
              <header class="mx-auto space-y-3">
                <p class="text-xs font-semibold uppercase tracking-[0.34em] text-text-muted">
                  Dukung live stream
                </p>
                <h1 class="font-display text-4xl font-semibold tracking-tight text-balance text-text sm:text-5xl">
                  Bikin stream makin seru & kasih semangat!
                </h1>
                <p class="max-w-2xl text-sm leading-6 text-text-muted sm:text-base">
                  Pilih nominal, buat QRIS, lalu scan. Notifikasi tampil di stream setelah pembayaran terkonfirmasi.
                </p>
              </header>

              <div class="mx-auto max-w-xl rounded-[2.25rem] border border-stroke/60 bg-background/14 px-5 py-6 shadow-sm shadow-black/25 ring-1 ring-stroke/35 backdrop-blur sm:px-6 sm:py-7">
                <.form
                  for={@form}
                  id="donation-form"
                  phx-change="validate"
                  phx-submit="submit"
                  class="space-y-6"
                >
                  <div class="space-y-2">
                    <p class="text-sm font-medium text-text-muted">
                      Isi nama, pilih nominal, lalu lanjut.
                    </p>
                    <div class="h-px bg-stroke/60" />
                  </div>

                  <.input
                    field={@form[:donor_name]}
                    label="Nama kamu"
                    placeholder="Riza"
                    autocomplete="name"
                    autofocus
                    required
                  />

                  <fieldset class="space-y-3">
                    <legend class="w-full">
                      <span class="flex items-center justify-between gap-3">
                        <span class="text-sm font-semibold text-text">Pilih nominal</span>
                        <span class="text-xs uppercase tracking-[0.2em] text-text-muted">IDR</span>
                      </span>
                    </legend>

                    <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
                      <label
                        :for={preset <- @preset_amounts}
                        for={preset.id}
                        class={
                          amount_option_classes(
                            selected_amount_option == preset.option,
                            preset.recommended?
                          )
                        }
                      >
                        <input
                          id={preset.id}
                          type="radio"
                          name={@form[:amount_option].name}
                          value={preset.value}
                          checked={selected_amount_option == preset.option}
                          class="sr-only"
                        />

                        <div class="flex items-start justify-between gap-3">
                          <div class="space-y-1">
                            <span class="block text-sm font-semibold text-text">
                              {preset.title}
                            </span>
                            <span class="block text-lg font-bold tracking-tight text-text">
                              Rp {preset.formatted}
                            </span>
                          </div>
                          <span
                            :if={selected_amount_option == preset.option}
                            class="mt-0.5 text-accent"
                          >
                            <span class="hero-check-circle"></span>
                          </span>
                        </div>
                        <span class="text-xs text-text-muted">
                          {preset.hint}
                        </span>
                      </label>

                      <label
                        for="donation_form_amount_option_custom"
                        class={amount_option_classes(selected_amount_option == "custom", false)}
                      >
                        <input
                          id="donation_form_amount_option_custom"
                          type="radio"
                          name={@form[:amount_option].name}
                          value="custom"
                          checked={selected_amount_option == "custom"}
                          class="sr-only"
                        />
                        <div class="space-y-1.5">
                          <span class="text-base font-semibold text-text">Nominal lain</span>
                        </div>
                        <span class="text-xs text-text-muted">Masukkan angka</span>
                      </label>
                    </div>

                    <p :if={amount_option_error} class="text-sm font-medium text-danger">
                      {amount_option_error}
                    </p>
                  </fieldset>

                  <div
                    :if={selected_amount_option == "custom"}
                    class="rounded-3xl border border-stroke/60 bg-background/14 px-4 py-4"
                  >
                    <.input
                      field={@form[:custom_amount]}
                      type="number"
                      label="Nominal custom"
                      placeholder="15000"
                      min="1000"
                      step="1000"
                      required
                    />
                    <div class="mt-2 flex flex-wrap items-center justify-between gap-2 text-xs">
                      <span class="text-text-muted">Masukkan angka tanpa titik atau koma.</span>
                      <span
                        :if={parse_custom_amount(@form[:custom_amount].value) > 0}
                        class="font-semibold text-accent"
                      >
                        Nominal: Rp {DonationPresenter.format_idr(
                          parse_custom_amount(@form[:custom_amount].value)
                        )}
                      </span>
                    </div>
                  </div>

                  <.input
                    field={@form[:message]}
                    type="textarea"
                    label="Pesan (opsional)"
                    rows="4"
                    maxlength="160"
                    placeholder="Tulis pesan, request lagu, atau kasih semangat..."
                  />

                  <div class="space-y-3 pt-2">
                    <button
                      type="submit"
                      class="group inline-flex w-full items-center justify-between rounded-3xl bg-accent px-5 py-4 text-left text-sm font-semibold text-background shadow-sm shadow-accent/25 ring-1 ring-accent/30 transition hover:bg-accent/92 active:bg-accent/88 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent phx-submit-loading:pointer-events-none phx-submit-loading:opacity-70"
                    >
                      <span class="space-y-0.5">
                        <span class="block text-base">Dukung Sekarang</span>
                        <span class="block text-[11px] font-semibold text-background/70 uppercase tracking-wide">
                          Pembayaran via QRIS
                        </span>
                      </span>
                      <span class="inline-flex items-center gap-2">
                        <span class="phx-submit-loading:hidden" aria-hidden="true">&rarr;</span>
                        <span class="hidden phx-submit-loading:inline-flex items-center gap-2 text-xs font-semibold">
                          <span class="hero-arrow-path motion-safe:animate-spin"></span> Memproses
                        </span>
                      </span>
                    </button>

                    <div class="mt-4 flex items-center justify-center gap-2 rounded-2xl bg-surface/30 px-3 py-2.5 text-center shadow-inner ring-1 ring-stroke/30">
                      <span class="text-xs font-medium text-text-muted">
                        Bisa bayar pakai GoPay, OVO, DANA, ShopeePay & semua M-Banking
                      </span>
                    </div>
                  </div>
                </.form>
              </div>
            </div>
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
    |> validate_required([:donor_name], message: "Tulis namamu dulu")
    |> validate_length(:donor_name, max: 40, message: "Maksimal 40 karakter")
    |> validate_amount()
    |> validate_length(:message, max: 160, message: "Pesan maksimal 160 karakter")
  end

  defp validate_amount(changeset) do
    case get_field(changeset, :amount_option) do
      option when option in @preset_amount_options ->
        changeset

      "custom" ->
        changeset
        |> validate_required([:custom_amount], message: "Masukkan nominal donasi")
        |> validate_number(:custom_amount,
          greater_than_or_equal_to: 1_000,
          message: "Minimal 1000"
        )
        |> validate_change(:custom_amount, fn :custom_amount, amount ->
          validate_custom_amount_step(amount)
        end)

      _ ->
        add_error(changeset, :amount_option, "Pilih nominal donasi")
    end
  end

  defp validate_custom_amount_step(amount)
       when is_integer(amount) and rem(amount, 1_000) == 0,
       do: []

  defp validate_custom_amount_step(_amount),
    do: [custom_amount: "Harus kelipatan 1000"]

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

  defp preset_amount_copy(5_000), do: {"Traktir Kopi ☕", "Biar melek terus", false}
  defp preset_amount_copy(10_000), do: {"Cemilan Stream 🍟", "Paling sering dipilih", true}
  defp preset_amount_copy(25_000), do: {"Sponsor Sultan 👑", "Support maksimal!", false}

  defp preset_amount_copy(_amount), do: {"Support", "Terima kasih", false}

  defp amount_option_classes(selected?, recommended?)

  defp amount_option_classes(true, _recommended?) do
    [
      "group relative flex min-h-28 cursor-pointer flex-col justify-between overflow-hidden rounded-3xl border px-4 py-4 transition-all duration-200",
      "scale-[1.02] border-accent/50 bg-linear-to-br from-accent/16 via-background/12 to-accent-2/12 shadow-md shadow-accent/25 ring-1 ring-accent/30 active:scale-100"
    ]
  end

  defp amount_option_classes(false, true) do
    [
      "group relative flex min-h-28 cursor-pointer flex-col justify-between overflow-hidden rounded-3xl border px-4 py-4 transition-all duration-200",
      "border-stroke/60 bg-background/14 ring-1 ring-accent/10 hover:border-accent/35 hover:bg-background/18 active:scale-[0.99]"
    ]
  end

  defp amount_option_classes(false, false) do
    [
      "group relative flex min-h-28 cursor-pointer flex-col justify-between overflow-hidden rounded-3xl border px-4 py-4 transition-all duration-200",
      "border-stroke/60 bg-background/14 hover:border-stroke hover:bg-background/18 active:scale-[0.99]"
    ]
  end

  defp parse_custom_amount(nil), do: 0
  defp parse_custom_amount(""), do: 0
  defp parse_custom_amount(val) when is_integer(val), do: val

  defp parse_custom_amount(val) when is_binary(val) do
    case Integer.parse(val) do
      {num, _} -> num
      :error -> 0
    end
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
      {:ok, donation} ->
        Logger.info(
          "Pending donation created donation_id=#{donation.id} mayar_transaction_id=#{donation.mayar_transaction_id} amount=#{donation.amount}"
        )

        {:ok, donation}

      {:error, %Ecto.Changeset{} = donation_changeset} ->
        {:error, donation_changeset, qr}
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
    base_message = "QR belum bisa dibuat sekarang. Coba lagi ya."

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
    "Donasi belum bisa disimpan. Coba lagi ya. Kalau kamu sudah sempat scan QR, jangan lanjutkan pembayarannya."
  end

  defp log_failed_donation_persist(%Client.DynamicQr{} = qr, amount, donation_changeset) do
    Logger.warning(
      "Could not persist pending donation mayar_transaction_id=#{qr.mayar_transaction_id} amount=#{amount} errors=#{inspect(changeset_error_summary(donation_changeset))}"
    )
  end
end
