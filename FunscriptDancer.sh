#!/usr/bin/env bash

julia --project --threads auto -e "using Pkg; Pkg.instantiate(); using FunscriptDancer; julia_main()"