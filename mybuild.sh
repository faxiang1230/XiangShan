#!/bin/bash
make init
make emu EMU_THREADS=8 EMU_TRACE=1 -j
mv build single-build
make emu EMU_THREADS=8 EMU_TRACE=1 NUM_CORES=2 -j
mv build dual-build


