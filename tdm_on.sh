#!/bin/bash
./SmcDumpKey MVHR 1
sleep 1
./SmcDumpKey MVMR 2
sleep 2

./tdm_unblank.sh