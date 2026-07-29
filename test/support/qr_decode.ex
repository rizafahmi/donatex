defmodule Notable.QrDecode do
  @moduledoc """
  Test helper that decodes a rendered QR code with OpenCV's `QRCodeDetector`.

  The `/qr` page is displayed live on stream for viewers to scan with real
  phones, so "it looks like a QR code" is not evidence. Every visual change to
  the QR has to be checked against an actual decoder, and that check has to be
  cheap enough to run on each change rather than once at the end.

  OpenCV lives in Python, so this module shells out to `qr_decode.py`. Pixels
  are handed over as a headerless RGB8 buffer, which keeps the Elixir side free
  of any image-encoder or SVG-rasteriser dependency.
  """

  @script Path.join(__DIR__, "qr_decode.py")

  @typedoc "A raw RGB8 image as produced by `Notable.Qr.render_rgb/2`."
  @type image :: %{width: pos_integer(), height: pos_integer(), data: binary()}

  @typedoc """
  How much abuse the code survives, from `decode/2` with `margin: true`.

  * `:smallest_px` – smallest square render (px) that still decoded
  * `:max_blur_kernel` – largest Gaussian blur kernel that still decoded
  * `:min_contrast` – lowest contrast factor (1.0 = untouched) that still decoded
  """
  @type margin :: %{
          smallest_px: pos_integer() | nil,
          max_blur_kernel: non_neg_integer() | nil,
          min_contrast: float() | nil
        }

  @doc """
  Returns true when OpenCV is importable, so tests can explain a skip rather
  than fail confusingly on a machine without it.
  """
  @spec available?() :: boolean()
  def available? do
    case System.cmd("python3", ["-c", "import cv2"], stderr_to_stdout: true) do
      {_output, 0} -> true
      _ -> false
    end
  rescue
    ErlangError -> false
  end

  @doc """
  Decodes a raw RGB8 image and returns `{:ok, decoded}` or `{:error, reason}`.

  With `margin: true` the result is `{:ok, decoded, margin}`, where the margin
  comes from a degradation ladder rather than a single pristine read.
  """
  @spec decode(image(), keyword()) ::
          {:ok, String.t()} | {:ok, String.t(), margin()} | {:error, term()}
  def decode(%{width: width, height: height, data: data}, opts \\ []) do
    path = Path.join(System.tmp_dir!(), "notable-qr-#{System.unique_integer([:positive])}.rgb")
    File.write!(path, data)

    try do
      run(%{kind: "raw", path: path, width: width, height: height}, opts)
    after
      File.rm(path)
    end
  end

  @doc """
  Decodes an image file (PNG, JPEG, …) from disk. Used for browser screenshots.
  """
  @spec decode_file(Path.t(), keyword()) ::
          {:ok, String.t()} | {:ok, String.t(), margin()} | {:error, term()}
  def decode_file(path, opts \\ []) do
    run(%{kind: "file", path: path}, opts)
  end

  defp run(spec, opts) do
    spec = Map.put(spec, :margin, Keyword.get(opts, :margin, false))

    case System.cmd("python3", [@script, JSON.encode!(spec)], stderr_to_stdout: true) do
      {output, 0} -> parse(output, spec.margin)
      {output, status} -> {:error, {:decoder_failed, status, String.trim(output)}}
    end
  end

  defp parse(output, want_margin?) do
    case JSON.decode(String.trim(output)) do
      {:ok, %{"value" => nil}} ->
        {:error, :not_decodable}

      {:ok, %{"value" => value, "margin" => margin}} when want_margin? ->
        {:ok, value, atomize(margin)}

      {:ok, %{"value" => value}} ->
        {:ok, value}

      {:ok, %{"error" => reason}} ->
        {:error, reason}

      _ ->
        {:error, {:unexpected_decoder_output, output}}
    end
  end

  defp atomize(margin) do
    %{
      smallest_px: margin["smallest_px"],
      max_blur_kernel: margin["max_blur_kernel"],
      min_contrast: margin["min_contrast"]
    }
  end
end
