defmodule NskCli.Device do
  defstruct [:id, :name, :type, :status, :ip]

  def actions(%__MODULE__{type: "Network"}) do
    ["Factory reset", "Follow logs", "SSH into IEx shell"]
  end

  def actions(%__MODULE__{type: "USB FEL"}) do
    [
      "Load FEL loaders",
      "fwup burn .fw",
      "Follow logs (USB)",
      "Reboot into FEL"
    ]
  end

  def actions(_), do: []

  def fake_devices do
    [
      %__MODULE__{id: "1", name: "Nerves Device 1", type: "Network", status: "Online", ip: "192.168.1.100"},
      %__MODULE__{id: "2", name: "Nerves Device 2", type: "USB FEL", status: "Connected", ip: nil}
    ]
  end
end
