defmodule NskCli.Actions.USB do
  require Logger

  @github_repo "gworkman/usb_fel_loaders"
  @filename "trellis.bin"

  defp cache_dir, do: Path.expand("~/.nerves/dl")

  def load_fel_loader(device_id, log_fun \\ fn _ -> :ok end) do
    with {:ok, version} <- get_latest_version(log_fun),
         {:ok, path} <- ensure_cached(version, log_fun),
         :ok <- execute_loader(path, device_id, log_fun) do
      {:ok, "Loaded FEL loader #{version}"}
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, "Unknown error: #{inspect(error)}"}
    end
  end

  defp get_latest_version(log_fun) do
    log_fun.("Fetching latest release info from GitHub...")
    url = "https://api.github.com/repos/#{@github_repo}/releases/latest"

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        version = body["tag_name"]
        log_fun.("Found version: #{version}")
        {:ok, version}

      {:ok, %{status: status}} ->
        {:error, "GitHub API returned status #{status}"}

      {:error, reason} ->
        {:error, "Failed to fetch release info: #{inspect(reason)}"}
    end
  end

  defp ensure_cached(version, log_fun) do
    dir = cache_dir()
    File.mkdir_p!(dir)
    path = Path.join(dir, "trellis-#{version}.bin")

    if File.exists?(path) do
      log_fun.("Using cached file: #{path}")
      {:ok, path}
    else
      log_fun.("Downloading #{version} to #{path}...")
      download_file(version, path)
    end
  end

  defp execute_loader(path, device_id, log_fun) do
    log_fun.("Applying loader to device #{device_id}...")
    Sunxi.FEL.execute_uboot(path, device: device_id)
  end

  defp download_file(version, path) do
    url = "https://github.com/#{@github_repo}/releases/download/#{version}/#{@filename}"

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        File.write!(path, body)
        {:ok, path}

      {:ok, %{status: status}} ->
        {:error, "Download failed with status #{status}"}

      {:error, reason} ->
        {:error, "Failed to download file: #{inspect(reason)}"}
    end
  end
end
