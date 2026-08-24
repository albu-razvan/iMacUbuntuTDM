#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Run this script as root:${NC}"
    echo "  sudo $0"
    exit 1
fi

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo
        echo -e "${RED}Installation did not complete.${NC}"
        echo -e "Run the uninstaller to clean up partial changes."
    fi
}

trap cleanup EXIT

# repository location
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

ON_SCRIPT="$SCRIPT_DIR/tdm_on.sh"
OFF_SCRIPT="$SCRIPT_DIR/tdm_off.sh"
BLANK_SCRIPT="$SCRIPT_DIR/tdm_blank.sh"
TOGGLE_SRC="$SCRIPT_DIR/tdm-toggle"
BUTTON_ACTION_SRC="$SCRIPT_DIR/tdm-button-action"
INIT_SRC="$SCRIPT_DIR/tdm-init"
INIT_SERVICE_SRC="$SCRIPT_DIR/tdm-init.service"
POWER_SERVICE_SRC="$SCRIPT_DIR/tdm-power-button.service"
SMC_DUMPKEY="$SCRIPT_DIR/SmcDumpKey.c"
SMC_DUMPKEY_BIN="$SCRIPT_DIR/SmcDumpKey"

echo
echo -e "${BOLD}${BLUE}============================================================${NC}"
echo -e "${BOLD}${BLUE} TDM setup${NC}"
echo -e "${BOLD}${BLUE}============================================================${NC}"
echo
echo -e "Repository: ${BOLD}$SCRIPT_DIR${NC}"
echo

# check repository files

if [[ ! -f "$ON_SCRIPT" ]]; then
    echo -e "${RED}ERROR: $ON_SCRIPT does not exist.${NC}"
    exit 1
fi

if [[ ! -f "$OFF_SCRIPT" ]]; then
    echo -e "${RED}ERROR: $OFF_SCRIPT does not exist.${NC}"
    exit 1
fi

if [[ ! -f "$BLANK_SCRIPT" ]]; then
    echo -e "${RED}ERROR: $BLANK_SCRIPT does not exist.${NC}"
    exit 1
fi

if [[ ! -f "$TOGGLE_SRC" ]]; then
    echo -e "${RED}ERROR: $TOGGLE_SRC does not exist.${NC}"
    exit 1
fi

if [[ ! -f "$BUTTON_ACTION_SRC" ]]; then
    echo -e "${RED}ERROR: $BUTTON_ACTION_SRC does not exist.${NC}"
    exit 1
fi

if [[ ! -f "$INIT_SRC" ]]; then
    echo -e "${RED}ERROR: $INIT_SRC does not exist.${NC}"
    exit 1
fi

if [[ ! -f "$INIT_SERVICE_SRC" ]]; then
    echo -e "${RED}ERROR: $INIT_SERVICE_SRC does not exist.${NC}"
    exit 1
fi

if [[ ! -f "$POWER_SERVICE_SRC" ]]; then
    echo -e "${RED}ERROR: $POWER_SERVICE_SRC does not exist.${NC}"
    exit 1
fi

if [[ ! -f "$SMC_DUMPKEY" ]]; then
    echo -e "${RED}ERROR: $SMC_DUMPKEY does not exist.${NC}"
    exit 1
fi

# install dependencies

echo -e "${YELLOW}Installing required packages...${NC}"

apt-get update
apt-get install -y build-essential evtest libdrm-tests

# make TDM scripts executable

if [[ ! -x "$ON_SCRIPT" ]]; then
    echo -e "${YELLOW}Making tdm_on.sh executable...${NC}"
    chmod +x "$ON_SCRIPT"
fi

if [[ ! -x "$OFF_SCRIPT" ]]; then
    echo -e "${YELLOW}Making tdm_off.sh executable...${NC}"
    chmod +x "$OFF_SCRIPT"
fi

if [[ ! -x "$BLANK_SCRIPT" ]]; then
    echo -e "${YELLOW}Making tdm_blank.sh executable...${NC}"
    chmod +x "$BLANK_SCRIPT"
fi

if [[ ! -x "$BUTTON_ACTION_SRC" ]]; then
    echo -e "${YELLOW}Making tdm-button-action executable...${NC}"
    chmod +x "$BUTTON_ACTION_SRC"
fi

# compile SmcDumpKey

echo
echo -e "${YELLOW}Compiling SmcDumpKey...${NC}"

gcc -O2 -Wall \
    -o "$SMC_DUMPKEY_BIN" \
    "$SMC_DUMPKEY"

chmod 755 "$SMC_DUMPKEY_BIN"

echo -e "Built: ${GREEN}$SMC_DUMPKEY_BIN${NC}"

# ---------------------------------------------------------------------------
# Configure systemd-logind BEFORE touching the power button
#
# This is deliberately done before device discovery. The installer will ask
# the user to press the physical power button during discovery, and we do not
# want systemd-logind to interpret that press as a shutdown request.
# ---------------------------------------------------------------------------

echo
echo -e "${YELLOW}Configuring systemd-logind...${NC}"

mkdir -p /etc/systemd/logind.conf.d

cat > /etc/systemd/logind.conf.d/tdm-power.conf <<'EOF'
[Login]
HandlePowerKey=ignore
EOF

echo -e "${YELLOW}Restarting systemd-logind...${NC}"

systemctl restart systemd-logind.service

echo
echo -e "${GREEN}systemd-logind is now configured to ignore the power button.${NC}"

# select power-button event device

DEVICE_CONFIRMED=false

while [[ "$DEVICE_CONFIRMED" == "false" ]]; do

    echo
    echo -e "${YELLOW}Looking for power-button devices...${NC}"

    POWER_DEVICES=()

    for dev in /dev/input/event*; do
        [[ -e "$dev" ]] || continue

        if ! evtest --query "$dev" EV_KEY KEY_POWER >/dev/null 2>&1; then
            continue
        fi

        dev_name="$(
            awk -v target="${dev##*/}" '
                BEGIN { RS=""; FS="\n" }
                {
                    handlers=""
                    name=""
                    for (i = 1; i <= NF; i++) {
                        if ($i ~ /^N: Name=/) name=$i
                        if ($i ~ /^H: Handlers=/) handlers=$i
                    }
                    if (handlers != "") {
                        n = split(handlers, parts, " ")
                        for (j = 1; j <= n; j++) {
                            if (parts[j] == target) {
                                sub(/^N: Name=/, "", name)
                                print name
                                exit
                            }
                        }
                    }
                }
            ' /proc/bus/input/devices
        )"

        if [[ "$dev_name" == *"Power Button"* ]]; then
            POWER_DEVICES+=("$dev")
        fi
    done

    if [[ ${#POWER_DEVICES[@]} -eq 0 ]]; then
        echo
        echo -e "${RED}ERROR: No power-button device supporting KEY_POWER was found.${NC}"
        echo
        echo "Run:"
        echo "  sudo evtest"
        echo
        echo "to inspect the available input devices."
        exit 1
    fi

    echo
    echo -e "${BOLD}Power-button devices found:${NC}"
    echo

    for i in "${!POWER_DEVICES[@]}"; do
        dev="${POWER_DEVICES[$i]}"

        event_name="$(
            awk -v target="${dev##*/}" '
                BEGIN { RS=""; FS="\n" }
                {
                    handlers=""
                    name=""
                    for (i = 1; i <= NF; i++) {
                        if ($i ~ /^N: Name=/) name=$i
                        if ($i ~ /^H: Handlers=/) handlers=$i
                    }
                    if (handlers != "") {
                        n = split(handlers, parts, " ")
                        for (j = 1; j <= n; j++) {
                            if (parts[j] == target) {
                                sub(/^N: Name=/, "", name)
                                print name
                                exit
                            }
                        }
                    }
                }
            ' /proc/bus/input/devices
        )"

        if [[ -z "$event_name" ]]; then
            event_name="Unknown device"
        fi

        echo -e "  ${BLUE}[$((i + 1))] $dev${NC}"
        echo "      $event_name"
        echo
    done

    if [[ ${#POWER_DEVICES[@]} -eq 1 ]]; then

        POWER_DEVICE="${POWER_DEVICES[0]}"

        echo "Only one power-button device found."
        echo -e "Using: ${GREEN}$POWER_DEVICE${NC}"

    else

        while true; do

            read -rp \
                "Select the power-button device [1-${#POWER_DEVICES[@]}]: " \
                selection

            if [[ "$selection" =~ ^[0-9]+$ ]] &&
               (( selection >= 1 && selection <= ${#POWER_DEVICES[@]} )); then

                POWER_DEVICE="${POWER_DEVICES[$((selection - 1))]}"
                break
            fi

            echo -e "${RED}Invalid selection.${NC}"
        done
    fi

    # observe an actual button event to confirm

    echo
    echo -e "${BOLD}Selected device:${NC}"
    echo -e "  ${GREEN}$POWER_DEVICE${NC}"
    echo
    echo "Press and release the physical power button once."
    echo
    echo "The button is currently ignored by systemd-logind."
    echo "This should NOT shut down the machine."
    echo

    TMP_OUTPUT="$(mktemp)"

    /usr/bin/evtest "$POWER_DEVICE" < /dev/null > "$TMP_OUTPUT" 2>&1 &
    EVTEST_PID=$!

    START_TIME=$(date +%s)

    echo -e "${YELLOW}Waiting for power-button event... (timeout: 10s)${NC}"
    echo -e "Press any key to select a different device."

    stty raw -echo
    while true; do

        if ! kill -0 "$EVTEST_PID" 2>/dev/null; then
            break
        fi

        if grep -q \
            'type 1 (EV_KEY), code 116 (KEY_POWER), value 0' \
            "$TMP_OUTPUT"; then

            break
        fi

        CURRENT_TIME=$(date +%s)
        ELAPSED=$((CURRENT_TIME - START_TIME))

        if [[ $ELAPSED -ge 10 ]]; then
            stty sane
            echo
            echo -e "${RED}Timeout reached (10s). No KEY_POWER release event detected.${NC}"
            kill "$EVTEST_PID" 2>/dev/null || true
            wait "$EVTEST_PID" 2>/dev/null || true
            rm -f "$TMP_OUTPUT"
            break
        fi

        if read -t 0.1 -n 1 _; then
            stty sane
            echo
            echo -e "${YELLOW}Selecting another device...${NC}"
            kill "$EVTEST_PID" 2>/dev/null || true
            wait "$EVTEST_PID" 2>/dev/null || true
            rm -f "$TMP_OUTPUT"
            break
        fi
    done
    stty sane

    kill "$EVTEST_PID" 2>/dev/null || true
    wait "$EVTEST_PID" 2>/dev/null || true

    if [[ -f "$TMP_OUTPUT" ]] && grep -q \
        'type 1 (EV_KEY), code 116 (KEY_POWER), value 0' \
        "$TMP_OUTPUT"; then

        DEVICE_CONFIRMED=true
        rm -f "$TMP_OUTPUT"

        echo
        echo -e "${GREEN}Power-button event detected successfully.${NC}"
    else
        rm -f "$TMP_OUTPUT"

        echo
        echo -e "${RED}Did not detect a KEY_POWER release event.${NC}"
        read -rp "Select another device? [Y/n]: " RETRY
        if [[ "$RETRY" =~ ^[Nn]$ ]]; then
            exit 1
        fi
    fi

done

EVENT_TYPE="1"
EVENT_CODE="116"
EVENT_NAME="KEY_POWER"
EVENT_VALUE="0"

echo
echo -e "${BOLD}Using:${NC}"
echo -e "  Device: ${GREEN}$POWER_DEVICE${NC}"
echo "  Event:  EV_KEY / KEY_POWER"
echo "  Code:   $EVENT_CODE"
echo "  Value:  $EVENT_VALUE (release)"

# confirmation

echo
read -rp "Continue with this device? [Y/n]: " CONFIRM

if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
    echo "Aborted."
    exit 0
fi

# default state on boot

DEFAULT_STATE=""

echo
echo -e "${BOLD}Select default state on boot:${NC}"
echo -e "  ${BLUE}[1] off${NC}  - blank screen (setterm --blank force)"
echo -e "  ${BLUE}[2] tty${NC}  - local console/TTY (setterm --blank poke + 0)"
echo -e "  ${BLUE}[3] tdm${NC}  - Target Display Mode"
echo
while true; do
    read -rp "Choice [1-3] (default 2 - tty): " DEFAULT_CHOICE
    # empty defaults to tty
    if [[ -z "$DEFAULT_CHOICE" ]]; then
        DEFAULT_CHOICE="2"
    fi
    case "$DEFAULT_CHOICE" in
        1|off|OFF)
            DEFAULT_STATE="off"
            break
            ;;
        2|tty|TTY)
            DEFAULT_STATE="tty"
            break
            ;;
        3|tdm|TDM)
            DEFAULT_STATE="tdm"
            break
            ;;
        *)
            echo -e "${RED}Invalid selection. Enter 1, 2, 3, off, tty, or tdm.${NC}"
            ;;
    esac
done

echo -e "${GREEN}Default boot state: $DEFAULT_STATE${NC}"

mkdir -p /etc/tdm
echo "$DEFAULT_STATE" > /etc/tdm/default_state
chmod 644 /etc/tdm/default_state
echo "$SCRIPT_DIR" > /etc/tdm/repo_dir
chmod 644 /etc/tdm/repo_dir
echo -e "${YELLOW}Saved default to /etc/tdm/default_state and repo to /etc/tdm/repo_dir${NC}"

# install TDM toggle and init scripts

echo
echo -e "${YELLOW}Installing /usr/local/sbin/tdm-toggle...${NC}"
cp "$TOGGLE_SRC" /usr/local/sbin/tdm-toggle
sed -i.bak "s|__TDM_DIR__|$SCRIPT_DIR|g" /usr/local/sbin/tdm-toggle
rm -f /usr/local/sbin/tdm-toggle.bak
chmod 755 /usr/local/sbin/tdm-toggle

echo -e "${YELLOW}Installing /usr/local/sbin/tdm-button-action...${NC}"
cp "$BUTTON_ACTION_SRC" /usr/local/sbin/tdm-button-action
chmod 755 /usr/local/sbin/tdm-button-action

echo -e "${YELLOW}Installing /usr/local/sbin/tdm-init...${NC}"
cp "$INIT_SRC" /usr/local/sbin/tdm-init
sed -i.bak "s|__TDM_DIR__|$SCRIPT_DIR|g" /usr/local/sbin/tdm-init
rm -f /usr/local/sbin/tdm-init.bak
chmod 755 /usr/local/sbin/tdm-init

# stop existing services

echo
echo -e "${YELLOW}Stopping existing TDM services...${NC}"

systemctl stop tdm-power-button.service 2>/dev/null || true
systemctl stop tdm-init.service 2>/dev/null || true

# install systemd services

echo -e "${YELLOW}Installing systemd services...${NC}"
cp "$INIT_SERVICE_SRC" /etc/systemd/system/tdm-init.service
chmod 644 /etc/systemd/system/tdm-init.service

cp "$POWER_SERVICE_SRC" /etc/systemd/system/tdm-power-button.service
sed -i.bak "s|__POWER_DEVICE__|$POWER_DEVICE|g" /etc/systemd/system/tdm-power-button.service
rm -f /etc/systemd/system/tdm-power-button.service.bak
chmod 644 /etc/systemd/system/tdm-power-button.service

# reload systemd

echo
echo -e "${YELLOW}Reloading systemd...${NC}"

systemctl daemon-reload

echo "tty" > /run/tdm_state
chmod 644 /run/tdm_state 2>/dev/null || true

# enable the services

echo
echo -e "${YELLOW}Enabling TDM services...${NC}"

systemctl enable tdm-init.service
systemctl enable tdm-power-button.service
systemctl start tdm-power-button.service

# ============================================================

echo
echo -e "${BOLD}${GREEN}============================================================${NC}"
echo -e "${BOLD}${GREEN} TDM setup complete${NC}"
echo -e "${BOLD}${GREEN}============================================================${NC}"
echo
echo "Input device:"
echo "  $POWER_DEVICE"
echo
echo "Default on boot:"
echo "  $DEFAULT_STATE  (/etc/tdm/default_state)"
echo
echo "Short press:"
echo "  toggle tty <-> tdm"
echo
echo "Double short press:"
echo "  turn the local screen off"
echo
echo "Long press:"
echo "  normal hardware/kernel shutdown"
echo
echo "Services:"
echo "  tdm-init.service (oneshot, applies default on boot)"
echo "  tdm-power-button.service (listens for KEY_POWER)"
echo
echo "Check status:"
echo "  sudo systemctl status tdm-power-button.service"
echo "  sudo systemctl status tdm-init.service"
echo "  cat /run/tdm_state"
echo "  cat /etc/tdm/default_state"
echo
echo "View logs:"
echo "  sudo journalctl -u tdm-power-button.service"
echo "  sudo journalctl -u tdm-init.service"
echo
echo "Change boot default later:"
echo "  echo tty | sudo tee /etc/tdm/default_state"
echo "  # or off, tdm"
echo
echo "============================================================"
