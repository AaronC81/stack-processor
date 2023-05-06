#!/bin/sh
set -e

ruby assemble.rb $1 > instruction_memory.v
apio build
tinyprog --pyserial -p hardware.bin
