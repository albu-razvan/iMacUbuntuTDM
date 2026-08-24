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

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo
echo -e "${BOLD}${BLUE}============================================================${NC}"
echo -e "${BOLD}${BLUE} TDM uninstaller${NC}"
echo -e "${BOLD}${BLUE}============================================================${NC}"
echo

# disable systemd services

echo -e "${YELLOW}Stopping and disabling TDM services...${NC}"

systemctl stop tdm-power-button.service 2>/dev/null || true
systemctl disable tdm-power-button.service 2>/dev/null || true
systemctl stop tdm-init.service 2>/dev/null || true
systemctl disable tdm-init.service 2>/dev/null || true

# remove systemd service files

SERVICE_FILE="/etc/systemd/system/tdm-power-button.service"
if [[ -f "$SERVICE_FILE" ]]; then
    echo -e "${YELLOW}Removing $SERVICE_FILE...${NC}"
    rm -f "$SERVICE_FILE"
fi

INIT_SERVICE_FILE="/etc/systemd/system/tdm-init.service"
if [[ -f "$INIT_SERVICE_FILE" ]]; then
    echo -e "${YELLOW}Removing $INIT_SERVICE_FILE...${NC}"
    rm -f "$INIT_SERVICE_FILE"
fi

# remove tdm scripts

TOGGLE_SCRIPT="/usr/local/sbin/tdm-toggle"
if [[ -f "$TOGGLE_SCRIPT" ]]; then
    echo -e "${YELLOW}Removing $TOGGLE_SCRIPT...${NC}"
    rm -f "$TOGGLE_SCRIPT"
fi

BUTTON_ACTION_SCRIPT="/usr/local/sbin/tdm-button-action"
if [[ -f "$BUTTON_ACTION_SCRIPT" ]]; then
    echo -e "${YELLOW}Removing $BUTTON_ACTION_SCRIPT...${NC}"
    rm -f "$BUTTON_ACTION_SCRIPT"
fi

INIT_SCRIPT="/usr/local/sbin/tdm-init"
if [[ -f "$INIT_SCRIPT" ]]; then
    echo -e "${YELLOW}Removing $INIT_SCRIPT...${NC}"
    rm -f "$INIT_SCRIPT"
fi

# remove systemd-logind configuration

LOGIND_CONF="/etc/systemd/logind.conf.d/tdm-power.conf"
if [[ -f "$LOGIND_CONF" ]]; then
    echo -e "${YELLOW}Removing $LOGIND_CONF...${NC}"
    rm -f "$LOGIND_CONF"
fi

LOGIND_DIR="/etc/systemd/logind.conf.d"
if [[ -d "$LOGIND_DIR" ]] && [[ -z "$(ls -A "$LOGIND_DIR")" ]]; then
    rmdir "$LOGIND_DIR"
fi

echo -e "${YELLOW}Restarting systemd-logind...${NC}"
systemctl restart systemd-logind.service

# remove compiled SmcDumpKey binary

SMC_DUMPKEY_BIN="$SCRIPT_DIR/SmcDumpKey"
if [[ -f "$SMC_DUMPKEY_BIN" ]]; then
    echo -e "${YELLOW}Removing $SMC_DUMPKEY_BIN...${NC}"
    rm -f "$SMC_DUMPKEY_BIN"
fi

# remove boot default config

DEFAULT_DIR="/etc/tdm"
DEFAULT_FILE="/etc/tdm/default_state"
REPO_FILE="/etc/tdm/repo_dir"
if [[ -f "$DEFAULT_FILE" ]]; then
    echo -e "${YELLOW}Removing $DEFAULT_FILE...${NC}"
    rm -f "$DEFAULT_FILE"
fi
if [[ -f "$REPO_FILE" ]]; then
    echo -e "${YELLOW}Removing $REPO_FILE...${NC}"
    rm -f "$REPO_FILE"
fi
if [[ -d "$DEFAULT_DIR" ]] && [[ -z "$(ls -A "$DEFAULT_DIR" 2>/dev/null)" ]]; then
    rmdir "$DEFAULT_DIR" 2>/dev/null || true
fi

# remove TDM state files

rm -f /run/tdm_state

# ensure VT is unblanked after uninstall (leave display on)
for tty in /dev/tty1 /dev/tty2 /dev/tty3 /dev/tty4 /dev/tty5 /dev/tty6 /dev/console; do
    if [[ -e "$tty" ]]; then
        setterm --blank poke --term linux < "$tty" > /dev/null 2>&1 || setterm --blank poke < "$tty" > /dev/null 2>&1 || true
    fi
done
setterm --blank poke --term linux 2>/dev/null || setterm --blank poke 2>/dev/null || true
echo 0 > /sys/class/graphics/fb0/blank 2>/dev/null || true
setterm --blank 0 --term linux 2>/dev/null || setterm --blank 0 2>/dev/null || true

# reload systemd

echo -e "${YELLOW}Reloading systemd...${NC}"
systemctl daemon-reload

# ============================================================

echo
echo -e "${BOLD}${GREEN}============================================================${NC}"
echo -e "${BOLD}${GREEN} TDM uninstall complete${NC}"
echo -e "${BOLD}${GREEN}============================================================${NC}"
echo
echo "Removed:"
echo "  - tdm-power-button.service"
echo "  - tdm-init.service"
echo "  - /usr/local/sbin/tdm-toggle"
echo "  - /usr/local/sbin/tdm-button-action"
echo "  - /usr/local/sbin/tdm-init"
echo "  - /etc/systemd/logind.conf.d/tdm-power.conf"
echo "  - $SMC_DUMPKEY_BIN"
echo "  - /etc/tdm/default_state"
echo "  - /etc/tdm/repo_dir"
echo "  - /run/tdm_state"
echo
echo -e "${YELLOW}Note: The following packages were NOT removed (may be needed by other software):${NC}"
echo "  - build-essential"
echo "  - evtest"
echo "  - libdrm-tests"
echo
echo -e "${YELLOW}To remove them manually:${NC}"
echo "  sudo apt-get remove --purge build-essential evtest libdrm-tests"
echo
echo "============================================================"
