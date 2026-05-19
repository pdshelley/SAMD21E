#!/usr/bin/env bash
set -euo pipefail

# Local helper for this machine: uses installed Swift snapshot toolchain.
TOOLCHAINS=swift make clean && TOOLCHAINS=swift make
