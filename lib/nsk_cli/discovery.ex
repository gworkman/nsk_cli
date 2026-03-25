defmodule NskCli.Discovery do
  alias NskCli.Device

  @doc """
  Discovers Nerves devices on the network and Allwinner devices in USB FEL mode.
  Normalizes both into a list of %NskCli.Device{} structs.
  """
  def discover do
    # Simulate scanning delay
    Process.sleep(500)

    network_devices = scan_network()
    usb_devices = scan_usb()
    mass_storage_devices = scan_mass_storage()

    network_devices ++ usb_devices ++ mass_storage_devices ++ fake_devices()
  end

  defp fake_devices do
    [
      %Device{
        id: "fake-net-1",
        name: "Kiosk Demo (rpi4)",
        type: "Network",
        status: "Online",
        ip: "192.168.7.48"
      },
      %Device{
        id: "93407200:7c004814:0102a04c:5c5b1cd8",
        name: "R528",
        type: "USB FEL",
        status: "Connected",
        ip: nil
      },
      %Device{
        id: "/dev/sdx",
        name: "/dev/sdx",
        type: "Mass Storage",
        status: "12345 bytes",
        ip: nil
      }
    ]
  end

  defp scan_network do
    NervesDiscovery.discover(timeout: 1_000)
    |> Enum.map(fn d ->
      ip =
        case d.addresses do
          [addr | _] when is_tuple(addr) ->
            addr |> Tuple.to_list() |> Enum.join(".")

          _ ->
            nil
        end

      # NervesDiscovery provides product and platform which are useful for the name
      name =
        cond do
          Map.get(d, :product) && Map.get(d, :platform) ->
            "#{d.product} (#{d.platform})"

          Map.get(d, :product) ->
            d.product

          true ->
            d.name
        end

      %Device{
        id: d.name,
        name: name,
        type: "Network",
        status: "Online",
        ip: ip
      }
    end)
  end

  defp scan_usb do
    case Sunxi.FEL.list_devices() do
      devices when is_list(devices) ->
        Enum.map(devices, fn d ->
          # Use sid if available, otherwise fallback to bus/device
          id = Map.get(d, :sid) || "usb-#{d.bus}-#{d.device}"

          %Device{
            id: id,
            name: d.model || "Allwinner Device",
            type: "USB FEL",
            status: "Connected",
            ip: nil
          }
        end)

      _ ->
        []
    end
  end

  defp scan_mass_storage do
    Fwup.get_devices()
    |> Enum.reject(&(&1 == [""]))
    |> Enum.map(fn [device, size] ->
      %Device{
        id: device,
        name: device,
        type: "Mass Storage",
        status: "#{size} bytes",
        ip: nil
      }
    end)
  end
end
