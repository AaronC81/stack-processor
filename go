#!/bin/sh
set -e
apio build
tinyprog --pyserial -p hardware.bin
