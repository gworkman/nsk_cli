defmodule NskCli.TUI do
  use ExRatatui.App
  alias ExRatatui.Widgets.Block
  alias ExRatatui.Widgets.Table
  alias ExRatatui.Widgets.Paragraph
  alias ExRatatui.Layout
  alias ExRatatui.Layout.Rect
  alias NskCli.Device

  @impl true
  def mount(_opts) do
    {:ok, %{devices: Device.fake_devices(), selected: 0}}
  end

  @impl true
  def render(state, frame) do
    area = %Rect{x: 0, y: 0, width: frame.width, height: frame.height}

    # Split the main area into body and footer
    [body, footer_area] = Layout.split(area, :vertical, [
      {:min, 0},
      {:length, 1}
    ])

    header = ["ID", "Name", "Type", "Status", "IP"]
    rows = Enum.map(state.devices, fn d ->
      [d.id, d.name, d.type, d.status, d.ip || "N/A"]
    end)

    table = %Table{
      header: header,
      rows: rows,
      widths: [
        {:length, 4},
        {:percentage, 30},
        {:length, 10},
        {:length, 10},
        {:length, 15}
      ],
      selected: state.selected,
      highlight_symbol: ">> ",
      block: %Block{
        title: " NSK CLI - Devices ",
        borders: [:all]
      }
    }

    footer = %Paragraph{
      text: " q: Quit | ↑/↓: Navigate | enter: Connect "
    }

    [
      {table, body},
      {footer, footer_area}
    ]
  end

  @impl true
  def handle_event(%ExRatatui.Event.Key{code: "q"}, state) do
    {:stop, state}
  end

  def handle_event(%ExRatatui.Event.Key{code: "down"}, state) do
    new_selected = min(state.selected + 1, length(state.devices) - 1)
    {:noreply, %{state | selected: new_selected}}
  end

  def handle_event(%ExRatatui.Event.Key{code: "up"}, state) do
    new_selected = max(state.selected - 1, 0)
    {:noreply, %{state | selected: new_selected}}
  end

  def handle_event(_event, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    # System.stop(0) might be needed in run.exs instead of here
    # to allow the GenServer to finish normally
    :ok
  end
end
