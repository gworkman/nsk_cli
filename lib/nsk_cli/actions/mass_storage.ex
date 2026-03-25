defmodule NskCli.Actions.MassStorage do
  require Logger

  @filename "name_badge.fw"

  defp cache_dir, do: Path.expand("~/.nerves/dl")

  def burn(device_id, log_fun \\ fn _ -> :ok end) do
    fw_path = Path.join(cache_dir(), @filename)

    if File.exists?(fw_path) do
      log_fun.("Found firmware: #{fw_path}")
      log_fun.("Burning to #{device_id}...")

      case Fwup.apply(device_id, "complete", fw_path) do
        {:ok, _pid} ->
          wait_for_fwup(log_fun)

        {:error, reason} ->
          log_fun.("Failed to start burn: #{inspect(reason)}")
          {:error, reason}
      end
    else
      log_fun.("Firmware not found at #{fw_path}")
      {:error, :file_not_found}
    end
  end

  defp wait_for_fwup(log_fun) do
    receive do
      {:fwup, {:progress, p}} ->
        log_fun.("Progress: #{p}%")
        wait_for_fwup(log_fun)

      {:fwup, {:ok, _code, msg}} ->
        log_fun.("Burn successful: #{msg}")
        {:ok, msg}

      {:fwup, {:error, _code, msg}} ->
        log_fun.("Burn failed: #{msg}")
        {:error, msg}

      {:fwup, {:warning, _code, msg}} ->
        log_fun.("Warning: #{msg}")
        wait_for_fwup(log_fun)
    after
      60_000 ->
        {:error, :timeout}
    end
  end
end
