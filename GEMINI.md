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
- Set up WiFi credentials

FEL devices:

- Load latest usb_fel_loaders firmware from GitHub or cache (reboots the device
  in USB mass storage mode)

USB Serial devices

- Follow logs from serial device
- Reboot into FEL mode using DTR and RTS signals

Mass storage devices:

- fwup burn .fw files
- Download and cache latest release files from a specified project

## Directives:

- use the ex_ratatui package to build the CLI
- use `nerves_discovery` and `sunxi` packages to detect devices on the network
  and via USB FEL mode, respectively. Also use `Fwup` elixir library to detect
  mass storage devices, and to flash `.fw` files. Use `circuits_uart` to
  interact with serial devices
- ALWAYS read the documentation on a module or function before using it.
  Documentation must be fetched with Tidewave `get_docs` tool.
- Always test the application to ensure that the functionality does as it
  expects. Tests should verify the output of the buffer
