#!/bin/bash

EMCC_CFLAGS="-I/emsdk/upstream/include -L/emsdk/upstream/lib -sINITIAL_MEMORY=26214400" EMCC_FORCE_STDLIBS=libc emmake make $1
