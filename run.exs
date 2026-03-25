# Ensure the application is started
Application.ensure_all_started(:nsk_cli)

# Start the TUI
{:ok, pid} = NskCli.TUI.start_link([])

# Monitor the process so we can wait for it to exit
ref = Process.monitor(pid)

# Wait for the process to exit
receive do
  {:DOWN, ^ref, :process, _pid, _reason} ->
    :ok
end
