defmodule Donatex.Qr do
  @moduledoc """
  Generates QR codes and matrix metadata for static URLs.
  """

  @quiet_zone 2

  @doc """
  Generates a QR code for the given text and returns a map with
  the SVG, matrix (quiet-zone stripped), size, and classified cells.
  """
  def generate(text) do
    qr = EQRCode.encode(text)
    raw = qr.matrix
    size = qr.modules

    matrix =
      0..(size - 1)
      |> Enum.map(fn row ->
        0..(size - 1)
        |> Enum.map(fn col ->
          get_in(raw, [Access.elem(row + @quiet_zone), Access.elem(col + @quiet_zone)])
        end)
      end)

    svg =
      EQRCode.svg(qr,
        color: "#1f1d2e",
        background_color: "#ffffff",
        width: 280,
        viewbox: true
      )

    %{
      text: text,
      size: size,
      matrix: matrix,
      cells: classify_cells(matrix, size),
      svg: svg
    }
  end

  @doc """
  Returns the configured public URL that the static QR code encodes.
  """
  def public_url do
    Donatex.Config.base_url() |> String.trim_trailing("/")
  end

  @doc """
  Classifies each cell in the matrix for CSS rendering.

  Each cell is a map with:
  - `:value` – 0 or 1
  - `:classes` – list of CSS class strings
  - `:element_index` – sequential index for data "on" cells (nil otherwise)
  """
  def classify_cells(matrix, size) do
    finder_positions = finder_positions(size)

    {cells, _acc} =
      matrix
      |> Enum.with_index()
      |> Enum.map_reduce(0, fn {row, row_idx}, acc ->
        {row_cells, new_acc} =
          row
          |> Enum.with_index()
          |> Enum.map_reduce(acc, fn {value, col_idx}, inner_acc ->
            assign_element_index(
              classify_cell(value, row_idx, col_idx, finder_positions),
              inner_acc
            )
          end)

        {row_cells, new_acc}
      end)

    cells
  end

  @doc """
  Returns the three finder pattern top-left positions:
  top-left, top-right, bottom-left.
  """
  def finder_positions(size) do
    [
      {0, 0, 0},
      {0, size - 7, 1},
      {size - 7, 0, 2}
    ]
  end

  defp assign_element_index(cell, acc) do
    cell = maybe_put_element_index(cell, acc)
    next_acc = if cell.element_index, do: acc + 1, else: acc
    {cell, next_acc}
  end

  defp maybe_put_element_index(%{value: 1, classes: classes} = cell, acc) do
    is_data_cell =
      not Enum.any?(classes, &String.starts_with?(&1, "qr-frame")) and
        not Enum.any?(classes, &String.starts_with?(&1, "qr-inner-frame"))

    if is_data_cell, do: %{cell | element_index: acc}, else: cell
  end

  defp maybe_put_element_index(cell, _acc), do: cell

  defp classify_cell(value, row, col, finder_positions) do
    case find_finder_pattern(row, col, finder_positions) do
      {:frame, idx} ->
        %{
          value: value,
          classes: ["qr-on-dot", "qr-frame-#{idx}", "is-qr-frame", "is-inside-qr-frame"],
          element_index: nil
        }

      {:inner_frame, idx} ->
        %{
          value: value,
          classes: ["qr-on-dot", "qr-inner-frame-#{idx}", "is-qr-inner-frame"],
          element_index: nil
        }

      {:inner_empty, idx} ->
        %{value: 0, classes: ["qr-off-dot", "qr-inner-empty-frame-#{idx}"], element_index: nil}

      nil ->
        if value == 1 do
          %{value: 1, classes: ["qr-on-dot"], element_index: nil}
        else
          %{value: 0, classes: ["qr-off-dot"], element_index: nil}
        end
    end
  end

  defp find_finder_pattern(row, col, positions) do
    Enum.find_value(positions, fn {fr, fc, idx} ->
      cond do
        # Outer 7×7 border
        on_outer_border?(row, col, fr, fc) ->
          {:frame, idx}

        # Inner 5×5 border
        on_inner_border?(row, col, fr, fc) ->
          {:inner_frame, idx}

        # Inside inner border (3×3 area)
        inside_inner?(row, col, fr, fc) ->
          {:inner_empty, idx}

        true ->
          nil
      end
    end)
  end

  defp on_outer_border?(row, col, fr, fc) do
    row in fr..(fr + 6) and col in fc..(fc + 6) and
      (row == fr or row == fr + 6 or col == fc or col == fc + 6)
  end

  defp on_inner_border?(row, col, fr, fc) do
    row in (fr + 1)..(fr + 5) and col in (fc + 1)..(fc + 5) and
      (row == fr + 1 or row == fr + 5 or col == fc + 1 or col == fc + 5)
  end

  defp inside_inner?(row, col, fr, fc) do
    row in (fr + 2)..(fr + 4) and col in (fc + 2)..(fc + 4)
  end
end
