defmodule NskCli.TUITest do
  use ExUnit.Case, async: true
  alias NskCli.TUI
  alias ExRatatui.Widgets.Table
  alias ExRatatui.Widgets.Paragraph
  alias ExRatatui.Event.Key
  alias ExRatatui.Frame

  test "mount/1 returns initial state with fake devices" do
    assert {:ok, state} = TUI.mount([])
    assert length(state.devices) == 2
    assert state.selected == 0
  end

  test "handle_event/2 handles arrow navigation keys" do
    {:ok, state} = TUI.mount([])

    # Go down
    assert {:noreply, state} = TUI.handle_event(%Key{code: "down"}, state)
    assert state.selected == 1

    # Don't go past the end
    assert {:noreply, state} = TUI.handle_event(%Key{code: "down"}, state)
    assert state.selected == 1

    # Go up
    assert {:noreply, state} = TUI.handle_event(%Key{code: "up"}, state)
    assert state.selected == 0

    # Don't go past the start
    assert {:noreply, state} = TUI.handle_event(%Key{code: "up"}, state)
    assert state.selected == 0
  end

  test "handle_event/2 handles quit" do
    {:ok, state} = TUI.mount([])
    assert {:stop, ^state} = TUI.handle_event(%Key{code: "q"}, state)
  end

  test "render/2 returns a table and a footer paragraph" do
    {:ok, state} = TUI.mount([])
    frame = %Frame{width: 80, height: 24}

    assert [
             {%Table{} = table, _body_rect},
             {%Paragraph{} = footer, _footer_rect}
           ] = TUI.render(state, frame)

    assert table.header == ["ID", "Name", "Type", "Status", "IP"]
    assert table.selected == 0
    assert footer.text =~ "↑/↓: Navigate"
  end
end
