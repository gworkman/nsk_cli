defmodule NskCli.TUI do
  use ExRatatui.App
  alias ExRatatui.Widgets.Block
  alias ExRatatui.Widgets.Table
  alias ExRatatui.Widgets.Paragraph
  alias ExRatatui.Widgets.Clear
  alias ExRatatui.Widgets.List
  alias ExRatatui.Widgets.Gauge
  alias ExRatatui.Widgets.Scrollbar
  alias ExRatatui.Layout
  alias ExRatatui.Layout.Rect
  alias ExRatatui.Style
  alias NskCli.Device
  alias NskCli.Discovery
  alias NskCli.TUI.NetworkActions
  alias NskCli.TUI.USBActions
  alias NskCli.TUI.MassStorageActions

  @refresh_interval 2_000

  @impl true
  def mount(_opts) do
    Task.async(fn -> Discovery.discover() end)

    {:ok,
     %{
       devices: [],
       selected: 0,
       selected_action: 0,
       focused: :devices,
       scanning?: true,
       status_message: nil,
       active_action: nil
     }}
  end

  @impl true
  def render(state, frame) do
    area = %Rect{x: 0, y: 0, width: frame.width, height: frame.height}

    # Main UI (Split Plane)
    main_ui = render_main_ui(state, area)

    # Popup Overlay
    if state.active_action do
      # Calculate centered popup area
      popup_width = round(frame.width * 0.8)
      popup_height = round(frame.height * 0.8)
      popup_x = max(0, div(frame.width - popup_width, 2))
      popup_y = max(0, div(frame.height - popup_height, 2))
      popup_area = %Rect{x: popup_x, y: popup_y, width: popup_width, height: popup_height}

      popup_widgets = render_active_action_overlay(state.active_action, popup_area)
      main_ui ++ popup_widgets
    else
      main_ui
    end
  end

  defp render_main_ui(state, area) do
    [body, footer_area] = Layout.split(area, :vertical, [{:min, 0}, {:length, 1}])

    [left_area, right_area] =
      Layout.split(body, :horizontal, [{:percentage, 50}, {:percentage, 50}])

    {devices_border_style, devices_highlight_style} = focus_styles(state.focused == :devices)

    devices_widget =
      if state.devices == [] and state.scanning? do
        %Paragraph{
          text: "\n Scanning...",
          alignment: :center,
          block: %Block{
            title: " Devices ",
            borders: [:all],
            border_style: devices_border_style,
            border_type: if(state.focused == :devices, do: :thick, else: :plain)
          }
        }
      else
        header = ["ID", "Name", "Type"]
        rows = Enum.map(state.devices, fn d -> [d.id, d.name, d.type] end)

        %Table{
          header: header,
          rows: rows,
          widths: [{:percentage, 30}, {:percentage, 40}, {:percentage, 30}],
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
      end

    selected_device = Enum.at(state.devices, state.selected)

    actions_widget =
      case selected_device do
        %Device{type: "Network"} ->
          NetworkActions.render(state, right_area, state.focused == :actions)

        %Device{type: "USB FEL"} ->
          USBActions.render(state, right_area, state.focused == :actions)

        %Device{type: "Mass Storage"} ->
          MassStorageActions.render(state, right_area, state.focused == :actions)

        nil ->
          {
            %Paragraph{
              text: "\n Select a device to see actions",
              alignment: :center,
              block: %Block{
                title: " Actions ",
                borders: [:all],
                border_style:
                  if(state.focused == :actions,
                    do: %Style{fg: :light_blue, modifiers: [:bold]},
                    else: %Style{fg: :gray}
                  ),
                border_type: if(state.focused == :actions, do: :thick, else: :plain)
              }
            },
            # Return tuple to match {widget, rect}
            right_area
          }
      end

    # Unpack actions_widget tuple if it was returned as such (NetworkActions/USBActions return {widget, rect})
    {actions_widget_content, _} = actions_widget

    status_text = if state.status_message, do: " | Status: #{state.status_message}", else: ""

    footer = %Paragraph{
      text: " q: Quit | ↑/↓: Navigate | ←/→: Switch Panel | enter: Run Action#{status_text} ",
      style: %Style{fg: :gray}
    }

    [
      {devices_widget, left_area},
      {actions_widget_content, right_area},
      {footer, footer_area}
    ]
  end

  defp render_active_action_overlay(action, area) do
    block = %Block{
      title: " #{action.title} (↑/↓: Scroll | x: Close) ",
      borders: [:all],
      border_type: :rounded,
      border_style: %Style{fg: :light_blue, modifiers: [:bold]}
    }

    # Manually calculate inner area (assuming borders: [:all] takes 1 cell on each side)
    inner_area = %Rect{
      x: area.x + 1,
      y: area.y + 1,
      width: max(0, area.width - 2),
      height: max(0, area.height - 2)
    }
    
    # Split inner area vertically: Progress (optional) | Logs
    {progress_area, content_area} =
      if action.progress do
        [p, c] = Layout.split(inner_area, :vertical, [{:length, 3}, {:min, 0}])
        {p, c}
      else
        {nil, inner_area}
      end

    # Split content area horizontally: Logs | Scrollbar
    [logs_area, scroll_area] = Layout.split(content_area, :horizontal, [{:min, 0}, {:length, 1}])

    # Widgets
    clear = %Clear{}
    
    gauge = if action.progress do
      %Gauge{
        ratio: action.progress / 100.0,
        label: "#{action.progress}%",
        gauge_style: %Style{fg: :light_blue, modifiers: [:bold]},
        block: %Block{borders: [:bottom], border_style: %Style{fg: :gray}}
      }
    end

    list = %List{
      items: action.logs,
      selected: action.selected_log,
      highlight_style: %Style{bg: :gray, fg: :white},
      highlight_symbol: " "
    }

    scrollbar = %Scrollbar{
      orientation: :vertical_right,
      content_length: length(action.logs),
      position: action.selected_log,
      viewport_content_length: logs_area.height
    }

    widgets = [
      {clear, area},
      {block, area}
    ]

    widgets = if gauge, do: widgets ++ [{gauge, progress_area}], else: widgets
    widgets ++ [{list, logs_area}, {scrollbar, scroll_area}]
  end

  defp focus_styles(focused?) do
    if focused? do
      {%Style{fg: :light_blue, modifiers: [:bold]},
       %Style{fg: :black, bg: :light_blue, modifiers: [:bold]}}
    else
      {%Style{fg: :gray}, %Style{modifiers: [:reversed]}}
    end
  end

  # Event Handling

  @impl true
  def handle_event(%ExRatatui.Event.Key{code: "q"}, state) do
    {:stop, state}
  end

  # Intercept 'x' to cancel active action
  def handle_event(%ExRatatui.Event.Key{code: "x"}, %{active_action: %{task: task_pid}} = state) do
    Process.exit(task_pid, :kill)
    {:noreply, %{state | active_action: nil, status_message: "Action cancelled"}}
  end

  # Ignore other keys if action is active (modal behavior)
  def handle_event(%ExRatatui.Event.Key{code: "up"}, %{active_action: action} = state) do
    new_selected = min(action.selected_log + 1, length(action.logs) - 1)
    {:noreply, put_in(state.active_action.selected_log, new_selected)}
  end

  def handle_event(%ExRatatui.Event.Key{code: "down"}, %{active_action: action} = state) do
    new_selected = max(action.selected_log - 1, 0)
    {:noreply, put_in(state.active_action.selected_log, new_selected)}
  end

  def handle_event(_event, %{active_action: %{}} = state) do
    {:noreply, state}
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

  def handle_event(event, %{focused: :actions} = state) do
    dispatch_action_event(event, state)
  end

  def handle_event(_event, state) do
    {:noreply, state}
  end

  defp dispatch_action_event(event, state) do
    selected_device = Enum.at(state.devices, state.selected)

    case selected_device do
      %Device{type: "Network"} -> NetworkActions.handle_event(event, state)
      %Device{type: "USB FEL"} -> USBActions.handle_event(event, state)
      %Device{type: "Mass Storage"} -> MassStorageActions.handle_event(event, state)
      _ -> {:noreply, state}
    end
  end

  # Info Handling

  @impl true
  def handle_info({:action_started, task, title}, state) do
    {:noreply,
     %{state | active_action: %{task: task, title: title, logs: ["Starting..."], progress: nil, selected_log: 0}}}
  end

  @impl true
  def handle_info({:action_progress, p}, state) do
    if state.active_action do
      {:noreply, put_in(state.active_action.progress, p)}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:action_log, msg}, state) do
    if state.active_action do
      # Prepend to logs (index 0 is newest)
      new_logs = Enum.take([msg | state.active_action.logs], 1000)
      
      # If user is at the top (index 0), they probably want to see new logs, 
      # so keep selected_log at 0.
      # If they scrolled up (index > 0), we increment to keep them at same log.
      new_selected = if state.active_action.selected_log > 0, do: state.active_action.selected_log + 1, else: 0
      new_selected = min(new_selected, length(new_logs) - 1)
      
      active_action = %{state.active_action | logs: new_logs, selected_log: new_selected}
      {:noreply, %{state | active_action: active_action}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:action_result, result}, state) do
    msg =
      case result do
        {:ok, m} -> "Success: #{m}"
        {:error, r} -> "Error: #{inspect(r)}"
      end

    if state.active_action do
      new_logs = Enum.take([msg | state.active_action.logs], 1000)
      active_action = %{state.active_action | logs: new_logs}
      {:noreply, %{state | active_action: active_action}}
    else
      # If action was cancelled or something, just update status
      {:noreply, %{state | status_message: msg}}
    end
  end

  @impl true
  def handle_info(:refresh_devices, state) do
    Task.async(fn -> Discovery.discover() end)
    {:noreply, %{state | scanning?: true}}
  end

  @impl true
  def handle_info(:clear_status, state) do
    {:noreply, Map.put(state, :status_message, nil)}
  end

  @impl true
  def handle_info({_ref, devices}, state) when is_list(devices) do
    # Try to keep selection stable if the device is still there
    selected_device = Enum.at(state.devices, state.selected)

    new_selected =
      if selected_device do
        Enum.find_index(devices, fn d -> d.id == selected_device.id end) || 0
      else
        0
      end

    Process.send_after(self(), :refresh_devices, @refresh_interval)
    {:noreply, %{state | devices: devices, selected: new_selected, scanning?: false}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Task finished (either discovery or action)
    # If it was the active action's task, we might want to note that?
    # But {:action_result} usually handles it if we used Task.async/await or similar.
    # If we used Task.start, we need to handle the down message if we linked.
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end
end
