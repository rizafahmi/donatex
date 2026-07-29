defmodule Notable.QrTest do
  @moduledoc """
  The `/qr` page is shown live on stream and scanned by real phones, so the
  only meaningful definition of "correct" here is "an actual decoder reads the
  right URL out of it".

  These tests therefore rasterise the QR and hand the pixels to OpenCV rather
  than asserting on markup. The important one is `:animation_peak`: it renders
  every module at the brightest state the animation can ever reach, so a pass
  bounds the whole animation instead of sampling one lucky frame.
  """

  use ExUnit.Case, async: true

  alias Notable.Qr
  alias Notable.QrDecode

  @url "https://feedback.rizafahmi.com"

  # Rendered at roughly the size the browser draws it (280 CSS px over ~29
  # modules), so the test exercises a realistic module size rather than an
  # unrealistically generous one.
  @module_px 10

  describe "matrix generation" do
    test "generates a square matrix for the public URL" do
      qr = Qr.generate(@url)

      assert qr.size > 0
      assert length(qr.matrix) == qr.size
      assert Enum.all?(qr.matrix, fn row -> length(row) == qr.size end)
      assert Enum.all?(List.flatten(qr.matrix), &(&1 in [0, 1]))
    end

    test "finder positions cover the three corners" do
      qr = Qr.generate(@url)
      size = qr.size

      assert Qr.finder_positions(size) == [{0, 0, 0}, {0, size - 7, 1}, {size - 7, 0, 2}]

      assert Qr.finder_index(0, 0, size) == 0
      assert Qr.finder_index(0, size - 1, size) == 1
      assert Qr.finder_index(size - 1, 0, size) == 2
      assert Qr.finder_index(div(size, 2), div(size, 2), size) == nil
    end
  end

  describe "scannability" do
    setup do
      unless QrDecode.available?() do
        flunk("""
        python3 with OpenCV is required to verify QR scannability.
        Install it with: python3 -m pip install opencv-python-headless
        """)
      end

      :ok
    end

    test "a plain render decodes to the public URL" do
      image = @url |> Qr.generate() |> Qr.render_rgb(module_px: @module_px)

      assert {:ok, @url} = QrDecode.decode(image)
    end

    test "the brightest frame the animation can produce still decodes" do
      image =
        @url
        |> Qr.generate()
        |> Qr.render_rgb(module_px: @module_px, variant: :animation_peak)

      assert {:ok, @url} = QrDecode.decode(image)
    end

    test "the brightest frame keeps a comfortable decode margin, not a bare pass" do
      image =
        @url
        |> Qr.generate()
        |> Qr.render_rgb(module_px: @module_px, variant: :animation_peak)

      assert {:ok, @url, margin} = QrDecode.decode(image, margin: true)

      # A code that only decodes at full size in a pristine render would fail
      # from a phone camera at an angle, in poor light, over a video stream.
      assert margin.smallest_px <= 160, "stops decoding below #{margin.smallest_px}px"
      assert margin.max_blur_kernel >= 5, "fails past a #{margin.max_blur_kernel}px blur"
      assert margin.min_contrast <= 0.35, "needs #{margin.min_contrast} contrast"
    end

    test "the quiet zone survives rendering" do
      image = @url |> Qr.generate() |> Qr.render_rgb(module_px: @module_px)
      quiet_px = Qr.quiet_zone() * @module_px

      assert image.width == image.height
      assert white_border?(image, quiet_px), "quiet zone is not pure white"
    end
  end

  describe "palette contract" do
    test "light modules stay pure white" do
      assert Qr.palette().background == "#ffffff"
      assert Qr.relative_luminance("#ffffff") == 1.0
    end

    test "every colour that can land on a dark module stays inside the ink budget" do
      # Per pixel, not per module average: a binariser thresholds pixels, so a
      # bright glyph punches holes in its module however thin it is.
      for colour <- Qr.ink_colours() do
        luminance = Qr.relative_luminance(colour)

        assert luminance <= Qr.max_ink_luminance(),
               "#{colour} has luminance #{luminance}, over the #{Qr.max_ink_luminance()} ink budget"
      end
    end

    test "the ink budget keeps real headroom below the measured decode edge" do
      # Measured against this matrix at 6-20 px per module: decoding held to
      # 0.262 and first failed at 0.305. Guard the headroom, not just the pass.
      assert Qr.max_ink_luminance() <= 0.305 / 1.8

      assert Qr.contrast_ratio(Qr.brightest_ink_luminance(), 1.0) >= 5.0
    end

    test "the scanner sweep can only darken modules, never lighten them" do
      palette = Qr.palette()

      assert palette.sweep_composite == "multiply"

      # Multiply against white leaves the sweep tint, so light modules stay
      # light enough to binarise apart from the brightest ink even at the
      # darkest point of the sweep gradient.
      swept_light =
        [palette.sweep, palette.sweep_core]
        |> Enum.map(&Qr.relative_luminance/1)
        |> Enum.min()

      assert Qr.contrast_ratio(Qr.brightest_ink_luminance(), swept_light) >= 4.5
    end

    test "any blend between palette colours also stays inside the budget" do
      # The renderer animates by interpolating between palette colours, so the
      # budget has to hold for the in-between frames, not just the endpoints.
      colours = Qr.ink_colours()

      for from <- colours, to <- colours, step <- 0..10 do
        blended = Qr.blend(from, to, step / 10)

        assert Qr.relative_luminance(blended) <= Qr.max_ink_luminance(),
               "#{from} -> #{to} at #{step / 10} yields #{blended}, over budget"
      end
    end

    test "the bolt polygon is a closed glyph drawn large enough to read" do
      palette = Qr.palette()

      assert length(palette.bolt_polygon) >= 5

      assert Enum.all?(palette.bolt_polygon, fn {x, y} ->
               x >= 0 and x <= 1 and y >= 0 and y <= 1
             end)

      # Safety is per-pixel, so the glyph can be bold without costing margin.
      assert palette.bolt_scale >= 0.8
      assert Qr.bolt_coverage() >= 0.1
    end
  end

  describe "PNG download source" do
    test "the SVG carries explicit dimensions so it cannot collapse to zero" do
      qr = Qr.generate(@url)

      assert Regex.match?(~r/<svg [^>]*\bwidth="280(\.0)?"/, qr.svg)
      assert Regex.match?(~r/<svg [^>]*\bheight="280(\.0)?"/, qr.svg)
    end

    test "the SVG is unanimated and uses only the plain two-tone palette" do
      qr = Qr.generate(@url)

      refute qr.svg =~ "<animate"
      refute qr.svg =~ "animation"
      refute qr.svg =~ "@keyframes"

      animated_only =
        Qr.palette().bolt_cycle ++ Qr.palette().finders ++ [Qr.palette().sweep]

      for colour <- animated_only do
        refute qr.svg =~ colour, "animation colour #{colour} leaked into the download SVG"
      end
    end

    test "the SVG paints exactly two colours" do
      # The downloaded PNG should be a flat, maximally scannable QR, not a
      # frame of the animation frozen in place.
      fills =
        Regex.scan(~r/style="fill: (#[0-9a-fA-F]{6});"/, Qr.generate(@url).svg,
          capture: :all_but_first
        )
        |> List.flatten()
        |> Enum.uniq()
        |> Enum.sort()

      assert fills == Enum.sort([Qr.palette().background, Qr.palette().plain])
    end

    test "the SVG the download path serialises decodes to the public URL" do
      image = @url |> Qr.generate() |> rasterize_svg()

      assert {:ok, @url} = QrDecode.decode(image)
    end
  end

  # --- helpers -------------------------------------------------------------

  defp white_border?(%{width: width, data: data}, border_px) do
    pixels = for <<r::8, g::8, b::8 <- data>>, do: {r, g, b}

    pixels
    |> Enum.with_index()
    |> Enum.all?(fn {pixel, index} ->
      x = rem(index, width)
      y = div(index, width)

      inside? =
        x >= border_px and y >= border_px and x < width - border_px and y < width - border_px

      inside? or pixel == {255, 255, 255}
    end)
  end

  # Rasterises the download SVG by reading back its `<rect>` elements. The SVG
  # is a grid of axis-aligned unit rects, so this is an exact rendering of the
  # artefact the browser turns into the downloaded PNG - no rasteriser needed.
  #
  # Attribute order is intentionally not assumed: EQRCode builds each rect from
  # a map, and map key enumeration order differs across OTP versions (OTP 27
  # on CI vs OTP 28 locally), so a fixed-order regex silently matched nothing
  # on Linux CI.
  defp rasterize_svg(qr) do
    scale = @module_px

    grid =
      Regex.scan(~r/<rect\b([^>]*?)\/>/, qr.svg, capture: :all_but_first)
      |> Enum.map(fn [attrs] -> parse_svg_rect(attrs) end)
      |> Map.new()

    assert map_size(grid) > 0

    # The SVG carries EQRCode's own quiet zone, so derive the grid extent from
    # the rects themselves rather than assuming our render margin.
    side = grid |> Map.keys() |> Enum.map(fn {x, _y} -> x end) |> Enum.max() |> Kernel.+(1)

    data =
      for y <- 0..(side * scale - 1), x <- 0..(side * scale - 1), into: <<>> do
        case Map.get(grid, {div(x, scale), div(y, scale)}, "#ffffff") do
          "#ffffff" -> <<255, 255, 255>>
          hex -> rgb_bytes(hex)
        end
      end

    %{width: side * scale, height: side * scale, data: data}
  end

  defp parse_svg_rect(attrs) do
    x = svg_attr!(attrs, "x") |> String.to_integer()
    y = svg_attr!(attrs, "y") |> String.to_integer()
    width = svg_attr!(attrs, "width")
    height = svg_attr!(attrs, "height")
    style = svg_attr!(attrs, "style")

    assert width == "1"
    assert height == "1"

    [fill] = Regex.run(~r/fill:\s*(#[0-9a-fA-F]{6})\b/, style, capture: :all_but_first)

    {{x, y}, fill}
  end

  defp svg_attr!(attrs, name) do
    case Regex.run(~r/\b#{name}="([^"]*)"/, attrs, capture: :all_but_first) do
      [value] -> value
      nil -> flunk("SVG <rect> missing attribute #{name}: #{attrs}")
    end
  end

  defp rgb_bytes("#" <> hex) do
    {r, g, b} = Qr.rgb(hex)
    <<r, g, b>>
  end
end
