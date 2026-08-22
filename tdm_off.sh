#!/bin/bash
# original flags: MVHR 0 / MVMR 2
# MVMR_OFF env allows trials without editing file: MVMR_OFF=0|1|2 ./tdm_off.sh
./SmcDumpKey MVHR 0
sleep 1
./SmcDumpKey MVMR "${MVMR_OFF:-2}"
sleep 2

# this seems to be the only way to return to the tty
# modetest exit trap manages to reset the display configuration
sudo timeout 5 modetest -M radeon -r </dev/null

# restore default console
sudo setupcon --current-tty
