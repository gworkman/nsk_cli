defmodule NskCli.TUITest do
  use ExUnit.Case, async: true
  alias NskCli.TUI
  alias ExRatatui.Widgets.Table
  alias ExRatatui.Widgets.List
  alias ExRatatui.Widgets.Paragraph
  alias ExRatatui.Event.Key
  alias ExRatatui.Frame

  test "mount/1 returns initial scanning state" do
    assert {:ok, state} = TUI.mount([])
    assert state.scanning? == true
    assert state.devices == []
  end

  test "handle_info/2 updates devices when task completes" do
    {:ok, state} = TUI.mount([])
    devices = [%NskCli.Device{id: "1", name: "Test", type: "Network"}]

    assert {:noreply, state} = TUI.handle_info({make_ref(), devices}, state)
    assert state.devices == devices
    assert state.scanning? == false
  end

  test "handle_event/2 handles focus switching" do
    {:ok, state} = TUI.mount([])
    # Setup some devices so selection works
    devices = [%NskCli.Device{id: "1", name: "Test", type: "Network"}]
    {:noreply, state} = TUI.handle_info({make_ref(), devices}, state)

    # Switch to actions
    assert {:noreply, state} = TUI.handle_event(%Key{code: "right"}, state)
    assert state.focused == :actions

    # Switch back to devices
    assert {:noreply, state} = TUI.handle_event(%Key{code: "left"}, state)
    assert state.focused == :devices
  end

  test "handle_event/2 handles navigation in both panels" do
    {:ok, state} = TUI.mount([])
    devices = [
      %NskCli.Device{id: "1", name: "D1", type: "Network"},
      %NskCli.Device{id: "2", name: "D2", type: "USB FEL"}
    ]
    {:noreply, state} = TUI.handle_info({make_ref(), devices}, state)

    # In devices panel
    assert {:noreply, state} = TUI.handle_event(%Key{code: "down"}, state)
    assert state.selected == 1

    # Switch to actions
    assert {:noreply, state} = TUI.handle_event(%Key{code: "right"}, state)
    assert state.focused == :actions

    # In actions panel (Device 2 is USB FEL, has 4 actions)
    assert {:noreply, state} = TUI.handle_event(%Key{code: "down"}, state)
    assert state.selected_action == 1
  end

  test "render/2 returns loading state initially" do
    {:ok, state} = TUI.mount([])
    frame = %Frame{width: 80, height: 24}

    # Should have 3 Paragraphs (Devices Loading, Actions Placeholder, Footer)
    assert [
             {%Paragraph{text: "\n Scanning..."}, _left_rect},
             {%Paragraph{text: "\n Select a device to see actions"}, _right_rect},
             {%Paragraph{} = footer, _footer_rect}
           ] = TUI.render(state, frame)
    
    assert footer.text =~ "q: Quit"
  end

  test "handle_info/2 updates status message" do
    {:ok, state} = TUI.mount([])
    
    assert {:noreply, new_state} = TUI.handle_info({:action_result, {:ok, "Done"}}, state)
    assert new_state.status_message == "Success: Done"
    
    assert {:noreply, cleared_state} = TUI.handle_info(:clear_status, new_state)
    assert cleared_state.status_message == nil
  end

  test "active action popup workflow" do
    {:ok, state} = TUI.mount([])
    
    # 1. Start Action
    task = Task.async(fn -> :ok end)
    {:noreply, state} = TUI.handle_info({:action_started, task.pid, "Test Action"}, state)
    
    assert state.active_action.title == "Test Action"
    assert state.active_action.logs == ["Starting..."]
    
    # 2. Render Popup
    frame = %Frame{width: 80, height: 24}
    widgets = TUI.render(state, frame)
    # Should have main UI + Popup
    assert length(widgets) > 3 
    {last_widget, _rect} = Elixir.List.last(widgets)
    assert last_widget.__struct__ == ExRatatui.Widgets.Popup
    
    # 3. Receive Logs
    {:noreply, state} = TUI.handle_info({:action_log, "Step 1"}, state)
    assert state.active_action.logs == ["Step 1", "Starting..."]
    
    # 4. Finish Action
    {:noreply, state} = TUI.handle_info({:action_result, {:ok, "Finished"}}, state)
    assert state.active_action.logs == ["Success: Finished", "Step 1", "Starting..."]
    
    # 5. Cancel/Close with 'x'
    {:noreply, state} = TUI.handle_event(%Key{code: "x"}, state)
    assert state.active_action == nil
    assert state.status_message == "Action cancelled"
  end

  test "render/2 returns table, list, and footer after discovery" do
    {:ok, state} = TUI.mount([])
    devices = [%NskCli.Device{id: "1", name: "D1", type: "Network"}]
    {:noreply, state} = TUI.handle_info({make_ref(), devices}, state)
    frame = %Frame{width: 80, height: 24}

    assert [
             {%Table{}, _left_rect},
             {%List{} = actions_list, _right_rect},
             {%Paragraph{}, _footer_rect}
           ] = TUI.render(state, frame)

    # Device 1 (Network) has 3 actions
    assert length(actions_list.items) == 3
  end

end
