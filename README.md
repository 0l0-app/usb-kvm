# usb-kvm

Turn a cheap 2:1 USB switch into a full KVM on Windows. Press the switch, and every monitor follows the keyboard to the other PC.

A small [AutoHotkey v2](https://www.autohotkey.com/) script runs on both PCs. It watches for the keyboard appearing or disappearing, then switches each monitor's input over DDC/CI using NirSoft's [ControlMyMonitor](https://www.nirsoft.net/utils/control_my_monitor.html). Neither needs an installer or admin rights.

## The setup it was built for

Two PCs share three monitors through their different inputs, and one keyboard sits on a USB switch.

| Monitor | Home PC input | Work PC input |
| --- | --- | --- |
| BenQ RL2455 (x2) | HDMI 1 (`17`) | DVI (`3`) |
| Dell P2418HT | DisplayPort (`3855`) | HDMI (`4369`) |

## How it works

- The script checks every 2 seconds, and on every Windows device-change event, whether the keyboard is present. A change has to hold for 1 second before it acts, so brief USB drop-outs around sleep and resume are ignored.
- **When the keyboard leaves a PC**, that PC sends every monitor to the other PC's inputs. This half does the real work, because many monitors (the BenQs here) only accept DDC/CI commands from the PC they are currently showing.
- **When the keyboard arrives at a PC**, it also tries to pull the monitors over. This is best effort: some monitors obey it and some ignore it.
- Because of that, **both PCs must be running the script.**

## Install (each PC, no admin)

1. Put these three files in one folder, for example `%LOCALAPPDATA%\Programs\usb-kvm`:
   - `usb-kvm.ahk` from this repo.
   - `AutoHotkey64.exe`, from the [AutoHotkey v2 download](https://www.autohotkey.com/download/) (the portable zip works without installing).
   - `ControlMyMonitor.exe`, from the [ControlMyMonitor zip](https://www.nirsoft.net/utils/controlmymonitor.zip).
2. Edit the settings at the top of `usb-kvm.ahk` (see [Configure](#configure)).
3. Drag `usb-kvm.ahk` onto `AutoHotkey64.exe`. A `usb-kvm.log` should appear next to the script, containing `started as home, keyboard present` (or `work` / `absent`).
4. To start it with Windows, press Win+R, run `shell:startup`, and create a shortcut there with this target:

   ```
   "%LOCALAPPDATA%\Programs\usb-kvm\AutoHotkey64.exe" "%LOCALAPPDATA%\Programs\usb-kvm\usb-kvm.ahk"
   ```

Do this on both PCs, then test the switch in both directions.

On a managed work PC, endpoint security such as SentinelOne may flag installer scripts, which is why there isn't one here. If it quarantines `AutoHotkey64.exe` or `ControlMyMonitor.exe`, ask IT for an exception.

## Configure

All settings are at the top of `usb-kvm.ahk`.

**`HOME_PC`** is the home PC's computer name (run `echo %COMPUTERNAME%`). Any other name is treated as the work PC.

**`KEYBOARD_IDS`** lists the keyboard's USB instance prefixes. Some keyboards show up under more than one product ID after a switch; mine appears as both `04d9:0207` and `04d9:1207`, so list every one you see. To find yours, run this in PowerShell, flip the switch, run it again, and compare:

```powershell
Get-PnpDevice -PresentOnly | ? InstanceId -match '^USB\\VID_' | ft FriendlyName, InstanceId
```

**Monitor serials** identify each monitor, instead of `\\.\DISPLAYn\Monitor0`, whose numbering changes between reboots and between PCs. Open `ControlMyMonitor.exe`, pick a monitor, and press Ctrl+M (Copy Monitor Strings) to get its serial.

**`INPUTS`** holds the VCP code `60` (Input Select) value for each monitor on each PC. Common values are DVI `3`, DisplayPort `15`, HDMI 1 `17` and HDMI 2 `18`, but read your own: from the PC a monitor is currently showing, run

```powershell
(Start-Process .\ControlMyMonitor.exe -ArgumentList '/GetValue SERIAL 60' -Wait -PassThru).ExitCode
```

Some monitors (the Dell here) report and need a 16-bit value, such as `3855` (`0x0F0F`) instead of `15`. Use whatever it reports. A reading of `0` means the monitor didn't answer, usually because it's showing the other PC.

## Hotkeys

Press these on the PC that is currently on screen.

| Hotkey | Action |
| --- | --- |
| Ctrl+Alt+F9 | Send all monitors to the other PC |
| Ctrl+Alt+F10 | Pull all monitors to this PC (only works for monitors that accept commands while showing the other PC) |

## Troubleshooting

- **Check the log on the PC you switched away from.** Every switch logs a line like `keyboard disconnected -> home inputs (exit 0)`.
- **Nothing is logged when you press the switch.** The keyboard has an ID you haven't listed; see `KEYBOARD_IDS`.
- **The switch is logged but a monitor doesn't move.** Confirm the input values with `/GetValue`, and check that DDC/CI is enabled in the monitor's on-screen menu.
- **The work PC logs "started as home"** (or the reverse). Fix `HOME_PC`.

## Why not display-switch?

[display-switch](https://github.com/haimgel/display-switch) is the well-known tool for this job, and I tried it first. It didn't fit this setup for three reasons:

- It watches a single USB ID, and this keyboard uses two.
- It relies on the arriving PC to switch the monitors, which these BenQs refuse.
- Windows named every monitor on the work PC "Generic PnP Monitor", so display-switch couldn't tell them apart.

Targeting monitors by serial number, and switching from the PC being left, avoids all three.

## License

MIT for the script. AutoHotkey and ControlMyMonitor are separate projects under their own licenses, and aren't included in this repo.
