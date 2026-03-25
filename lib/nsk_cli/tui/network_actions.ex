defmodule NskCli.TUI.NetworkActions do
  alias ExRatatui.Widgets.Block
  alias ExRatatui.Widgets.List
  alias NskCli.Device

  def render(state, rect, focused?) do
    selected_device = Enum.at(state.devices, state.selected)
    actions = Device.actions(selected_device)

    highlight_style =
      if focused? do
        %ExRatatui.Style{fg: :black, bg: :light_blue, modifiers: [:bold]}
      else
        %ExRatatui.Style{modifiers: [:reversed]}
      end

    border_style =
      if focused? do
        %ExRatatui.Style{fg: :light_blue, modifiers: [:bold]}
      else
        %ExRatatui.Style{fg: :gray}
      end

    widget = %List{
      items: actions,
      selected: state.selected_action,
      highlight_symbol: "> ",
      highlight_style: highlight_style,
      block: %Block{
        title: " Network Actions ",
        borders: [:all],
        border_style: border_style,
        border_type: if(focused?, do: :thick, else: :plain)
      }
    }

    {widget, rect}
  end

  def handle_event(%ExRatatui.Event.Key{code: "enter"}, state) do
    selected_device = Enum.at(state.devices, state.selected)
    actions = Device.actions(selected_device)
    action = Enum.at(actions, state.selected_action)

    case action do
      "Follow logs" ->
        parent = self()
        {:ok, pid} = Task.start(fn ->
          log_fun = fn msg -> send(parent, {:action_log, msg}) end
          result = NskCli.Actions.Network.follow_logs(selected_device.id, log_fun)
          send(parent, {:action_result, result})
        end)
        
        send(parent, {:action_started, pid, "Follow logs"})
        {:noreply, state}
        
      _ ->
        {:noreply, state}
    end
  end

  def handle_event(%ExRatatui.Event.Key{code: "down"}, state) do
    selected_device = Enum.at(state.devices, state.selected)
    actions = Device.actions(selected_device)
    new_selected = min(state.selected_action + 1, length(actions) - 1)
    {:noreply, %{state | selected_action: new_selected}}
  end

  def handle_event(%ExRatatui.Event.Key{code: "up"}, state) do
    new_selected = max(state.selected_action - 1, 0)
    {:noreply, %{state | selected_action: new_selected}}
  end

  def handle_event(_event, state) do
    {:noreply, state}
  end
end
