# NSK CLI

This project is the CLI tool for managing Nerves devices, particularly the
Nerves Starter Kit (NSK)

## Functions:

The primary function of the tool is to discover NSK devices on the network or
connected via USB (FEL mode), and to then allow the user to perform the
following actions on them:

Network devices:

- Factory reset
- Follow logs
- SSH into IEx shell

USB/FEL devices:

- Load latest usb_fel_loaders firmware from GitHub or cache (reboots the device
  in USB mass storage mode)
- fwup burn .fw file to USB mass storage
- Follow logs (via USB serial device)
- Reboot into FEL mode (via USB serial device)

## Directives:

- use the ex_ratatui package to build the CLI
- use `nerves_discovery` and `sunxi` packages to detect devices on the network
  and via USB FEL mode, respectively
- ALWAYS read the documentation on a module or function before using it.
  Documentation must be fetched with Tidewave `get_docs` tool.
- Create a `run.exs` file which starts a ExRatatui.App GenServer and waits for
  it to shutdown
- Always test the application to ensure that the functionality does as it
  expects
