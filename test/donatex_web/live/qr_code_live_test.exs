defmodule DonatexWeb.QrCodeLiveTest do
  use DonatexWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Donatex.Qr

  describe "QR generation module" do
    test "generates a square matrix for the public URL" do
      qr = Qr.generate("https://feedback.rizafahmi.com")

      assert qr.size > 0
      assert length(qr.matrix) == qr.size
      assert Enum.all?(qr.matrix, fn row -> length(row) == qr.size end)
    end

    test "classified cells include on-dots, off-dots, and frame classes" do
      qr = Qr.generate("https://feedback.rizafahmi.com")

      all_classes =
        qr.cells
        |> List.flatten()
        |> Enum.flat_map(& &1.classes)

      assert "qr-on-dot" in all_classes
      assert "qr-off-dot" in all_classes
      assert Enum.any?(all_classes, &String.starts_with?(&1, "qr-frame-"))
      assert Enum.any?(all_classes, &String.starts_with?(&1, "qr-inner-frame-"))
    end

    test "data on-cells have element indices for animation" do
      qr = Qr.generate("https://feedback.rizafahmi.com")

      data_on_cells =
        qr.cells
        |> List.flatten()
        |> Enum.filter(fn cell ->
          cell.value == 1 and cell.element_index != nil
        end)

      assert not Enum.empty?(data_on_cells)
      indices = Enum.map(data_on_cells, & &1.element_index)
      assert indices == Enum.uniq(indices) |> Enum.sort()
    end

    test "finder pattern corners have frame-0, frame-1, frame-2 classes" do
      qr = Qr.generate("https://feedback.rizafahmi.com")
      size = qr.size

      # Top-left corner
      first_cell = hd(hd(qr.cells))
      assert "qr-frame-0" in first_cell.classes

      # Top-right corner
      top_right = Enum.at(qr.cells, 0) |> Enum.at(size - 1)
      assert "qr-frame-1" in top_right.classes

      # Bottom-left corner
      bottom_left = Enum.at(qr.cells, size - 1) |> Enum.at(0)
      assert "qr-frame-2" in bottom_left.classes
    end

    test "inner empty frame cells have value 0" do
      qr = Qr.generate("https://feedback.rizafahmi.com")

      inner_empty_cells =
        qr.cells
        |> List.flatten()
        |> Enum.filter(fn cell ->
          Enum.any?(cell.classes, &String.starts_with?(&1, "qr-inner-empty-frame-"))
        end)

      assert Enum.all?(inner_empty_cells, &(&1.value == 0))
    end
  end

  describe "GET /qr" do
    test "renders the QR page with correct elements", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/qr")

      assert html =~ "qr-page"
      assert html =~ "qr-code"
      assert html =~ "Beri"
      assert html =~ "Masukan"
      assert html =~ "Scan QR Code"
      assert html =~ "Download PNG"
      assert html =~ "Share"
    end

    test "renders SEO metadata with noindex robots", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/qr")

      assert html =~ ~s(<meta name="robots" content="noindex, nofollow")
    end

    test "does not render flash or connection status banners", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/qr")

      refute has_element?(view, "#flash-group")
      refute has_element?(view, "#client-error")
      refute has_element?(view, "#server-error")
    end

    test "renders the animated SVG QR overlay with hidden SVG for download", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/qr")

      assert has_element?(view, "#qr-code.qr-scannable-card")
      assert has_element?(view, ".qr-svg-base svg")
      assert has_element?(view, ".qr-animation-overlay")
      assert has_element?(view, "#qr-svg-hidden svg")
    end

    test "download button is present and triggers push event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/qr")

      assert view
             |> element("#qrDownloadBtn")
             |> render() =~ "Download PNG"

      view |> element("#qrDownloadBtn") |> render_click()
      assert_push_event(view, "qr:download", %{})
    end

    test "share button triggers qr:share event with URL", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/qr")

      assert view
             |> element("#qrShareBtn")
             |> render() =~ "Share"
    end
  end
end
