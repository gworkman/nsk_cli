defmodule NskCli.TUI do
  use ExRatatui.App
  alias ExRatatui.Widgets.Block
  alias ExRatatui.Widgets.Table
  alias ExRatatui.Widgets.Paragraph
  alias ExRatatui.Widgets.Popup
  alias ExRatatui.Widgets.List
  alias ExRatatui.Widgets.Gauge
  alias ExRatatui.Widgets.WidgetList
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
    {:ok, %{
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
      popup_content = render_action_popup(state.active_action)
      
      popup = %Popup{
        content: popup_content,
        percent_width: 60,
        percent_height: 50,
        block: %Block{
          title: " #{state.active_action.title} ",
          borders: [:all],
          border_type: :rounded,
          border_style: %Style{fg: :light_blue, modifiers: [:bold]}
        }
      }
      
      # Render popup on top of main UI?
      # ExRatatui.App.render expects a list of {widget, rect} tuples.
      # The Popup widget in ExRatatui handles clearing the background, 
      # but we need to return it in the list *after* the main UI widgets so it draws on top.
      # However, ExRatatui's draw order is sequential.
      
      main_ui ++ [{popup, area}]
    else
      main_ui
    end
  end

  defp render_main_ui(state, area) do
    [body, footer_area] = Layout.split(area, :vertical, [{:min, 0}, {:length, 1}])
    [left_area, right_area] = Layout.split(body, :horizontal, [{:percentage, 33}, {:percentage, 67}])

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
          widths: [{:min, 8}, {:percentage, 60}, {:length, 13}],
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
        %Device{type: "Network"} -> NetworkActions.render(state, right_area, state.focused == :actions)
        %Device{type: "USB FEL"} -> USBActions.render(state, right_area, state.focused == :actions)
        %Device{type: "Mass Storage"} -> MassStorageActions.render(state, right_area, state.focused == :actions)
        nil ->
          {%Paragraph{
            text: "\n Select a device to see actions",
            alignment: :center,
            block: %Block{
              title: " Actions ",
              borders: [:all],
              border_style: if(state.focused == :actions, do: %Style{fg: :light_blue, modifiers: [:bold]}, else: %Style{fg: :gray}),
              border_type: if(state.focused == :actions, do: :thick, else: :plain)
            }
          }, right_area} # Return tuple to match {widget, rect}
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
  
  defp render_action_popup(action_state) do
    list = %List{
      items: Enum.reverse(action_state.logs),
      block: %Block{
        title: " Logs (Press 'x' to close) ",
        borders: [:all],
        border_style: %Style{fg: :gray}
      }
    }

    if action_state.progress do
      gauge = %Gauge{
        ratio: action_state.progress / 100.0,
        label: "#{action_state.progress}%",
        gauge_style: %Style{fg: :light_blue, modifiers: [:bold]},
        block: %Block{
          title: " Progress ",
          borders: [:all],
          border_style: %Style{fg: :light_blue}
        }
      }

      %WidgetList{
        widgets: [
          {gauge, %{height: 3}},
          {list, %{height: :fill}}
        ]
      }
    else
      list
    end
  end

  defp focus_styles(focused?) do
    if focused? do
      {%Style{fg: :light_blue, modifiers: [:bold]}, %Style{fg: :black, bg: :light_blue, modifiers: [:bold]}}
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
    {:noreply, %{state | active_action: %{task: task, title: title, logs: ["Starting..."], progress: nil}}}
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
      new_logs = [msg | state.active_action.logs]
      # Limit logs?
      {:noreply, put_in(state.active_action.logs, new_logs)}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:action_result, result}, state) do
    msg = case result do
      {:ok, m} -> "Success: #{m}"
      {:error, r} -> "Error: #{inspect(r)}"
    end
    
    if state.active_action do
       new_logs = [msg | state.active_action.logs]
       {:noreply, put_in(state.active_action.logs, new_logs)}
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
