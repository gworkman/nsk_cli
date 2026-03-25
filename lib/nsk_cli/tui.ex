defmodule NskCli.TUI do
  use ExRatatui.App
  alias ExRatatui.Widgets.Block
  alias ExRatatui.Widgets.Table
  alias ExRatatui.Widgets.List
  alias ExRatatui.Widgets.Paragraph
  alias ExRatatui.Layout
  alias ExRatatui.Layout.Rect
  alias ExRatatui.Style
  alias NskCli.Device

  @impl true
  def mount(_opts) do
    {:ok, %{devices: Device.fake_devices(), selected: 0, selected_action: 0, focused: :devices}}
  end

  @impl true
  def render(state, frame) do
    area = %Rect{x: 0, y: 0, width: frame.width, height: frame.height}

    # Split the main area into body and footer
    [body, footer_area] = Layout.split(area, :vertical, [
      {:min, 0},
      {:length, 1}
    ])

    # Split body into left (devices) and right (actions) - 33/67 split
    [left_area, right_area] = Layout.split(body, :horizontal, [
      {:percentage, 33},
      {:percentage, 67}
    ])

    header = ["ID", "Name", "Type"]
    rows = Enum.map(state.devices, fn d ->
      [d.id, d.name, d.type]
    end)

    # Styling based on focus
    {devices_border_style, devices_highlight_style} = if state.focused == :devices do
      {%Style{fg: :light_blue, modifiers: [:bold]}, %Style{fg: :black, bg: :light_blue, modifiers: [:bold]}}
    else
      {%Style{fg: :gray}, %Style{modifiers: [:reversed]}}
    end

    {actions_border_style, actions_highlight_style} = if state.focused == :actions do
      {%Style{fg: :light_blue, modifiers: [:bold]}, %Style{fg: :black, bg: :light_blue, modifiers: [:bold]}}
    else
      {%Style{fg: :gray}, %Style{modifiers: [:reversed]}}
    end

    table = %Table{
      header: header,
      rows: rows,
      widths: [
        {:length, 4},
        {:percentage, 60},
        {:length, 10}
      ],
      selected: state.selected,
      highlight_symbol: ">> ",
      highlight_style: devices_highlight_style,
      block: %Block{
        title: " Devices ",
        borders: [:all],
        border_style: devices_border_style,
        border_type: if(state.focused == :devices, do: :thick, else: :plain)
      }
    }

    selected_device = Enum.at(state.devices, state.selected)
    actions = Device.actions(selected_device)

    actions_list = %List{
      items: actions,
      selected: state.selected_action,
      highlight_symbol: "> ",
      highlight_style: actions_highlight_style,
      block: %Block{
        title: " Actions ",
        borders: [:all],
        border_style: actions_border_style,
        border_type: if(state.focused == :actions, do: :thick, else: :plain)
      }
    }

    footer = %Paragraph{
      text: " q: Quit | ↑/↓: Navigate | ←/→: Switch Panel | enter: Run Action ",
      style: %Style{fg: :gray}
    }

    [
      {table, left_area},
      {actions_list, right_area},
      {footer, footer_area}
    ]
  end

  @impl true
  def handle_event(%ExRatatui.Event.Key{code: "q"}, state) do
    {:stop, state}
  end

  def handle_event(%ExRatatui.Event.Key{code: "right"}, state) do
    {:noreply, %{state | focused: :actions}}
  end

  def handle_event(%ExRatatui.Event.Key{code: "left"}, state) do
    {:noreply, %{state | focused: :devices}}
  end

  def handle_event(%ExRatatui.Event.Key{code: "down"}, %{focused: :devices} = state) do
    new_selected = min(state.selected + 1, length(state.devices) - 1)
    {:noreply, %{state | selected: new_selected, selected_action: 0}}
  end

  def handle_event(%ExRatatui.Event.Key{code: "up"}, %{focused: :devices} = state) do
    new_selected = max(state.selected - 1, 0)
    {:noreply, %{state | selected: new_selected, selected_action: 0}}
  end

  def handle_event(%ExRatatui.Event.Key{code: "down"}, %{focused: :actions} = state) do
    selected_device = Enum.at(state.devices, state.selected)
    actions = Device.actions(selected_device)
    new_selected = min(state.selected_action + 1, length(actions) - 1)
    {:noreply, %{state | selected_action: new_selected}}
  end

  def handle_event(%ExRatatui.Event.Key{code: "up"}, %{focused: :actions} = state) do
    new_selected = max(state.selected_action - 1, 0)
    {:noreply, %{state | selected_action: new_selected}}
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
