#!/bin/bash
. ../../setup.sh
spackLoadUnique faodel
export LD_LIBRARY_PATH=$SPACK_LD_LIBRARY_PATH:$LD_LIBRARY_PATH

# TODO load an MPI library
