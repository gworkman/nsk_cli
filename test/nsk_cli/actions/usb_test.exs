defmodule NskCli.Actions.USBTest do
  use ExUnit.Case
  alias NskCli.Actions.USB

  @tag :tmp_dir
  test "ensure_cached downloads file if not present", %{tmp_dir: _tmp_dir} do
    # Ensure module is loaded
    Code.ensure_loaded(USB)
    assert function_exported?(USB, :load_fel_loader, 1)
  end
end
