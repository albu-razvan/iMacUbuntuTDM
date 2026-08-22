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

# disable systemd service

echo -e "${YELLOW}Stopping and disabling TDM power-button service...${NC}"

systemctl stop tdm-power-button.service 2>/dev/null || true
systemctl disable tdm-power-button.service 2>/dev/null || true

# remove systemd service file

SERVICE_FILE="/etc/systemd/system/tdm-power-button.service"
if [[ -f "$SERVICE_FILE" ]]; then
    echo -e "${YELLOW}Removing $SERVICE_FILE...${NC}"
    rm -f "$SERVICE_FILE"
fi

# remove tdm-toggle script

TOGGLE_SCRIPT="/usr/local/sbin/tdm-toggle"
if [[ -f "$TOGGLE_SCRIPT" ]]; then
    echo -e "${YELLOW}Removing $TOGGLE_SCRIPT...${NC}"
    rm -f "$TOGGLE_SCRIPT"
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

# remove TDM state file

rm -f /run/tdm_enabled

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
echo "  - /usr/local/sbin/tdm-toggle"
echo "  - /etc/systemd/logind.conf.d/tdm-power.conf"
echo "  - $SMC_DUMPKEY_BIN"
echo "  - /run/tdm_enabled"
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