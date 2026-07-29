defmodule Notable.Qr do
  @moduledoc """
  Generates the static QR code shown on `/qr` and `/qr-overlay`, plus the
  palette and geometry the animated canvas renderer draws with.

  The page is displayed live on stream for viewers to scan with real phones, so
  every decorative choice is bounded by whether a decoder can still read the
  code. Rather than leave that to eyeballing, the rules live here as data:

  * `palette/0` is the single source of truth for colour, shared with the JS
    renderer through a data attribute so the two cannot drift apart.
  * `render_rgb/2` rasterises the matrix, including an `:animation_peak`
    variant that paints every module at the brightest state the animation can
    ever reach. Decoding that one image bounds every frame in between.
  * `max_ink_luminance/0` and `contrast_ratio/2` express the budget the palette
    has to stay inside, so a future change that brightens a colour fails a test
    instead of quietly degrading scans.

  ## Why the budget is per-pixel

  The tempting model - "a bright bolt is fine as long as it covers a small
  share of the module, because the average stays dark" - is wrong, and a decode
  test caught it. Binarisers threshold individual pixels, so a bright glyph
  punches holes in its module no matter how thin it is.

  Sweeping a neutral grey bolt against the real matrix at render densities from
  6 to 20 px per module, decoding stayed reliable through relative luminance
  0.262 and first failed at 0.305. The budget is therefore set to 0.16, roughly
  half the observed failure point, so every colour that can land on a dark
  module has real headroom rather than scraping past.
  """

  # EQRCode already pads the raw matrix with a two-module quiet zone; we strip
  # it so callers get just the code, then re-add our own margin when rendering.
  @matrix_padding 2

  # Four modules is the margin the QR spec asks for. The canvas draws this
  # quiet zone itself; the scannable card uses padding: 0 so the margin is not
  # split between CSS and the renderer.
  @render_quiet_zone 4

  @svg_width 280

  # Ceiling on the relative luminance of any pixel drawn inside a dark module.
  # See the module doc for how this number was measured.
  @max_ink_luminance 0.16

  @palette %{
    background: "#ffffff",

    # The flat colour used by the downloadable PNG, which is deliberately not
    # animated: one dark tone on white, nothing else.
    plain: "#1f1d2e",

    # Data modules cycle through these as the flow wave travels across the
    # matrix. Kept at the very dark end of Rosé Pine's surface tones so the
    # bolt drawn on top has room to read against them.
    module_cycle: ["#191724", "#1f1d2e", "#26233a"],

    # Fill for a module a pathway pulse is currently passing through. This is
    # the brightest a module fill ever gets.
    pulse: "#403a63",

    # Lightning bolts are drawn at full opacity *inside* an already-solid
    # module. Bright neon bolts do not work here: a binariser thresholds per
    # pixel, not per module, so light pixels punch holes in the module however
    # small the glyph is. These are saturated jewel tones instead - vivid, but
    # inside the ink budget (see `max_ink_luminance/0`).
    # Deliberately sitting just under the budget rather than safely below it:
    # the bolts are the point of the design, so they take all the luminance
    # that is provably available.
    bolt_cycle: ["#31748f", "#9d5477", "#6b57a8"],

    # Because safety is per-pixel, glyph size costs nothing, so the bolt is
    # drawn large enough to read at a glance.
    bolt_scale: 0.86,

    # Lightning bolt as a closed polygon in a unit box, y pointing down. Kept
    # as data rather than an SVG path so its inked area is exactly computable
    # (see `bolt_coverage/0`) and the JS renderer draws the identical shape.
    bolt_polygon: [
      {0.62, 0.02},
      {0.14, 0.56},
      {0.46, 0.56},
      {0.38, 0.98},
      {0.86, 0.44},
      {0.54, 0.44}
    ],

    # Colour-coded finder patterns: purple, pink, blue. Solid fill, exact
    # geometry - the decoder locates the code by these, so only hue changes.
    finders: ["#3b2d5c", "#5c2a45", "#26405c"],

    # The scanner sweep is composited with `multiply`, which can only ever
    # darken. It tints the white quiet areas cyan while leaving dark modules
    # dark, so the sweep cannot reduce contrast no matter where it sits.
    # `sweep` is the band's soft edge, `sweep_core` its brighter centre line.
    # The core is the darkest the sweep ever makes a light module, so it is
    # capped by the contrast it has to keep against the brightest ink.
    sweep: "#f2fbfc",
    sweep_core: "#dcf4f8",
    sweep_composite: "multiply"
  }

  @doc """
  Generates a QR code for the given text.

  Returns the matrix (quiet zone stripped), its size, and an unanimated SVG
  used as the source for the PNG download.
  """
  def generate(text) do
    qr = EQRCode.encode(text)
    raw = qr.matrix
    size = qr.modules

    matrix =
      for row <- 0..(size - 1) do
        for col <- 0..(size - 1) do
          get_in(raw, [Access.elem(row + @matrix_padding), Access.elem(col + @matrix_padding)])
        end
      end

    %{
      text: text,
      size: size,
      matrix: matrix,
      svg: svg(qr)
    }
  end

  # `viewbox: true` makes EQRCode emit a viewBox *instead of* width/height,
  # leaving the SVG with no intrinsic size. That collapses it to 0x0 as a flex
  # item and makes the download rasterise at the 150px CSS default, so we take
  # the explicit dimensions instead.
  defp svg(qr) do
    EQRCode.svg(qr,
      color: @palette.plain,
      background_color: @palette.background,
      width: @svg_width
    )
  end

  @doc """
  Returns the configured public URL that the static QR code encodes.
  """
  def public_url do
    Notable.Config.base_url() |> String.trim_trailing("/")
  end

  @doc """
  The colour and geometry contract shared by the Elixir renderer and the JS
  canvas renderer. See the module doc for why it lives in one place.
  """
  def palette, do: @palette

  @doc """
  The palette in a JSON-encodable shape, handed to the canvas renderer through
  a data attribute so both renderers read the same numbers.
  """
  def client_palette do
    Map.update!(@palette, :bolt_polygon, fn points ->
      Enum.map(points, fn {x, y} -> [x, y] end)
    end)
  end

  @doc """
  Blends two colours in sRGB space, the way canvas compositing does.

  The renderer animates by interpolating between palette colours. That is safe
  by construction: relative luminance is convex in sRGB, so a blend of two
  colours can never be lighter than the lighter endpoint. Staying inside the
  ink budget at the endpoints therefore keeps every frame inside it too.
  """
  def blend(from, to, amount) when amount >= 0 and amount <= 1 do
    {r1, g1, b1} = rgb(from)
    {r2, g2, b2} = rgb(to)

    "#" <>
      ([{r1, r2}, {g1, g2}, {b1, b2}]
       |> Enum.map_join(fn {a, b} ->
         (a + (b - a) * amount) |> round() |> Integer.to_string(16) |> String.pad_leading(2, "0")
       end)
       |> String.downcase())
  end

  @doc "Quiet-zone margin, in modules, added around the matrix when rendering."
  def quiet_zone, do: @render_quiet_zone

  @doc """
  Returns the three finder pattern top-left positions as `{row, col, index}`:
  top-left, top-right, bottom-left.
  """
  def finder_positions(size) do
    [
      {0, 0, 0},
      {0, size - 7, 1},
      {size - 7, 0, 2}
    ]
  end

  @doc """
  Returns the index of the finder pattern covering `{row, col}`, or `nil`.
  """
  def finder_index(row, col, size) do
    Enum.find_value(finder_positions(size), fn {fr, fc, index} ->
      if row >= fr and row <= fr + 6 and col >= fc and col <= fc + 6, do: index
    end)
  end

  @doc """
  Splits a `#rrggbb` (or `rrggbb`) colour into its `{r, g, b}` components.
  """
  def rgb("#" <> hex), do: rgb(hex)

  def rgb(<<r::binary-2, g::binary-2, b::binary-2>>) do
    {String.to_integer(r, 16), String.to_integer(g, 16), String.to_integer(b, 16)}
  end

  @doc """
  WCAG relative luminance of a colour, 0.0 (black) to 1.0 (white).

  This is the quantity a decoder's binariser effectively averages over a
  module, which is why the palette budget is expressed in it.
  """
  def relative_luminance(colour) do
    {r, g, b} = rgb(colour)

    (0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b))
    |> Float.round(6)
  end

  defp channel(value) do
    srgb = value / 255

    if srgb <= 0.04045 do
      srgb / 12.92
    else
      :math.pow((srgb + 0.055) / 1.055, 2.4)
    end
  end

  @doc """
  WCAG contrast ratio between two relative luminances, from 1.0 to 21.0.
  """
  def contrast_ratio(a, b) do
    {lo, hi} = if a < b, do: {a, b}, else: {b, a}

    Float.round((hi + 0.05) / (lo + 0.05), 4)
  end

  @doc """
  The exact fraction of a module the lightning bolt inks, from the polygon's
  shoelace area scaled by `bolt_scale`.
  """
  def bolt_coverage do
    Float.round(polygon_area(@palette.bolt_polygon) * @palette.bolt_scale ** 2, 6)
  end

  defp polygon_area(points) do
    points
    |> Enum.zip(tl(points) ++ [hd(points)])
    |> Enum.reduce(0.0, fn {{x1, y1}, {x2, y2}}, acc -> acc + (x1 * y2 - x2 * y1) end)
    |> Kernel./(2)
    |> abs()
  end

  @doc """
  The ceiling on the relative luminance of any pixel drawn inside a dark
  module. Every colour in `ink_colours/0` has to stay under it.
  """
  def max_ink_luminance, do: @max_ink_luminance

  @doc """
  Every colour the renderer can put on a dark module: fills, pathway pulses,
  bolts, and finder patterns. These are the colours the budget applies to.
  """
  def ink_colours do
    @palette.module_cycle ++ [@palette.pulse] ++ @palette.bolt_cycle ++ @palette.finders
  end

  @doc """
  Relative luminance of the lightest colour the renderer can put on a dark
  module - the brightest single pixel the animation can produce.
  """
  def brightest_ink_luminance do
    ink_colours() |> Enum.map(&relative_luminance/1) |> Enum.max()
  end

  @doc """
  Rasterises a generated QR into a raw RGB8 image, quiet zone included.

  ## Options

  * `:module_px` - pixels per module (default `10`)
  * `:quiet_zone` - margin in modules (default `quiet_zone/0`)
  * `:variant` - `:plain` for the flat two-tone render that models the PNG
    download, or `:animation_peak` for the brightest state the animated canvas
    can reach: pulse-lit fills, colour-coded finders, and the lightest bolt
    painted into every data module at once.
  """
  def render_rgb(qr, opts \\ []) do
    module_px = Keyword.get(opts, :module_px, 10)
    quiet = Keyword.get(opts, :quiet_zone, @render_quiet_zone)
    variant = Keyword.get(opts, :variant, :plain)

    size = qr.size
    width = (size + 2 * quiet) * module_px

    spec = %{
      size: size,
      quiet: quiet,
      module_px: module_px,
      variant: variant,
      rows: qr.matrix |> Enum.map(&List.to_tuple/1) |> List.to_tuple(),
      fill: peak_fill(variant),
      bolt: peak_bolt(variant),
      finders: Enum.map(@palette.finders, &bytes/1),
      mask: if(variant == :animation_peak, do: bolt_mask(module_px), else: MapSet.new())
    }

    data =
      for y <- 0..(width - 1), x <- 0..(width - 1), into: <<>> do
        pixel(spec, x, y)
      end

    %{width: width, height: width, data: data}
  end

  @white <<255, 255, 255>>

  defp pixel(spec, x, y) do
    row = div(y, spec.module_px) - spec.quiet
    col = div(x, spec.module_px) - spec.quiet

    if outside?(spec, row, col) or elem(elem(spec.rows, row), col) == 0 do
      @white
    else
      module_pixel(spec, row, col, rem(y, spec.module_px), rem(x, spec.module_px))
    end
  end

  defp outside?(%{size: size}, row, col) do
    row < 0 or col < 0 or row >= size or col >= size
  end

  defp module_pixel(%{variant: :plain} = spec, _row, _col, _py, _px), do: spec.fill

  defp module_pixel(spec, row, col, py, px) do
    cond do
      index = finder_index(row, col, spec.size) -> Enum.at(spec.finders, index)
      MapSet.member?(spec.mask, {py, px}) -> spec.bolt
      true -> spec.fill
    end
  end

  defp peak_fill(:plain), do: bytes(@palette.plain)
  defp peak_fill(:animation_peak), do: bytes(@palette.pulse)

  defp peak_bolt(:plain), do: bytes(@palette.plain)

  defp peak_bolt(:animation_peak) do
    @palette.bolt_cycle
    |> Enum.max_by(&relative_luminance/1)
    |> bytes()
  end

  defp bytes(colour) do
    {r, g, b} = rgb(colour)
    <<r, g, b>>
  end

  # Which pixels of a single module the bolt glyph inks, computed once and
  # reused for every module.
  defp bolt_mask(module_px) do
    scale = @palette.bolt_scale

    for py <- 0..(module_px - 1),
        px <- 0..(module_px - 1),
        u = ((px + 0.5) / module_px - 0.5) / scale + 0.5,
        v = ((py + 0.5) / module_px - 0.5) / scale + 0.5,
        inside_polygon?(@palette.bolt_polygon, u, v),
        into: MapSet.new() do
      {py, px}
    end
  end

  # Ray casting: a point is inside when a ray to the right crosses an odd
  # number of edges.
  defp inside_polygon?(points, x, y) do
    points
    |> Enum.zip(tl(points) ++ [hd(points)])
    |> Enum.reduce(false, fn {{x1, y1}, {x2, y2}}, inside ->
      if y1 > y != y2 > y and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1 do
        not inside
      else
        inside
      end
    end)
  end
end
