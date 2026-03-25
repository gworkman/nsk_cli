defmodule NskCli.TUITest do
  use ExUnit.Case, async: true
  alias NskCli.TUI
  alias ExRatatui.Widgets.Table
  alias ExRatatui.Widgets.List
  alias ExRatatui.Widgets.Paragraph
  alias ExRatatui.Event.Key
  alias ExRatatui.Frame

  test "mount/1 returns initial state with focus on devices" do
    assert {:ok, state} = TUI.mount([])
    assert state.focused == :devices
    assert state.selected == 0
  end

  test "handle_event/2 handles focus switching" do
    {:ok, state} = TUI.mount([])

    # Switch to actions
    assert {:noreply, state} = TUI.handle_event(%Key{code: "right"}, state)
    assert state.focused == :actions

    # Switch back to devices
    assert {:noreply, state} = TUI.handle_event(%Key{code: "left"}, state)
    assert state.focused == :devices
  end

  test "handle_event/2 handles navigation in both panels" do
    {:ok, state} = TUI.mount([])

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

  test "render/2 returns table, list, and footer" do
    {:ok, state} = TUI.mount([])
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
