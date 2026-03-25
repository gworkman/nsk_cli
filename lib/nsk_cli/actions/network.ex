defmodule NskCli.Actions.Network do
  @moduledoc """
  Actions for network-connected Nerves devices.
  """

  def follow_logs(device_id, log_fun \\ fn _ -> :ok end) do
    log_fun.("Connecting to #{device_id}...")
    
    # We use RingLogger.attach() to stream logs. 
    # -tt forces a pseudo-terminal which might be needed for some interactive commands,
    # but for streaming logs we might not want it if we want clean output.
    # Nerves SSH typically handles this well.
    
    ssh_args = [
      "-o", "StrictHostKeyChecking=no",
      "-o", "UserKnownHostsFile=/dev/null",
      device_id,
      "RingLogger.attach()"
    ]

    port = Port.open({:spawn_executable, System.find_executable("ssh")}, [
      :binary,
      :exit_status,
      :stderr_to_stdout,
      args: ssh_args
    ])

    stream_logs(port, log_fun)
  end

  defp stream_logs(port, log_fun) do
    receive do
      {^port, {:data, data}} ->
        # Data might contain multiple lines or partial lines
        data
        |> String.split(["\r\n", "\n"])
        |> Enum.reject(&(&1 == ""))
        |> Enum.each(log_fun)
        
        stream_logs(port, log_fun)

      {^port, {:exit_status, status}} ->
        if status == 0 do
          {:ok, "SSH connection closed"}
        else
          {:error, "SSH exited with status #{status}"}
        end
    after
      # If we don't get data for a long time, we keep waiting 
      # unless the user kills the task.
      1000 ->
        stream_logs(port, log_fun)
    end
  end
end
