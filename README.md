# iMac Ubuntu TDM

Turn an old iMac into an external display using Target Display Mode on Ubuntu.

## Compatible models

This should only work on these two iMac models, as they are the only ones with both a supported SMC and Mini DisplayPort input:

| Model                     | Identifier       |
| ------------------------- | ---------------- |
| iMac (27-inch, Late 2009) | iMac10,1 / A1312 |
| iMac (27-inch, Mid 2010)  | iMac11,3 / A1312 |

I've only personally tested this on **iMac11,3** running **Ubuntu Server 24.04 LTS**. Other models/OS combos may behave differently.

## What it does

Pressing the physical power button toggles Target Display Mode. The iMac switches between its own desktop and acting as a display for another device connected via Mini DisplayPort.

- **Single short press**: toggles between local console and TDM
- **Double short press**: turns the local screen off
- **Long press**: normal hardware shutdown (as usual)

## Usage

```bash
git clone https://github.com/alburazvan/iMacUbuntuTDM.git
cd iMacUbuntuTDM

sudo ./install.sh
```

The installer will:

1. Install dependencies (`build-essential`, `evtest`)
2. Compile `SmcDumpKey`
3. Configure systemd-logind to ignore the power button
4. Helps identify the power-button event to use
5. Create a systemd service that listens for power-button presses

## Uninstall

```bash
sudo ./uninstall.sh
```

## Credits

- [smc_util](https://github.com/floe/smc_util) by floe
- [SmcDumpKey.c](https://www.contrib.andrew.cmu.edu/~somlo/OSXKVM/) from SOMLO/OSXKVM
- [powermetrics.d](https://gist.github.com/beltex/acbbeef815a7be938abf) by beltex
