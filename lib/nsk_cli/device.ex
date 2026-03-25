defmodule NskCli.Device do
  defstruct [:id, :name, :type, :status, :ip]

  def actions(%__MODULE__{type: "Network"}) do
    ["Factory reset", "Follow logs", "SSH into IEx shell"]
  end

  def actions(%__MODULE__{type: "USB FEL"}) do
    [
      "Load FEL loaders",
      "Follow logs (USB)",
      "Reboot into FEL"
    ]
  end

  def actions(%__MODULE__{type: "Mass Storage"}) do
    [
      "Burn latest .fw file"
    ]
  end

  def actions(_), do: []
end
