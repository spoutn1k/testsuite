#!/bin/bash

#. ../setup.sh

#mpicc 
${TEST_CC_MPI} \
-I${SUPERLU_DIST_ROOT}/include \
-DUSE_VENDOR_BLAS -fopenmp -std=c99 -O3 -DPRNTlevel=1 -DDEBUGlevel=0 -fPIE \
-o pdcompute_resid.c.o -c pdcompute_resid.c

#mpicc 
${TEST_CC_MPI} \
-I${SUPERLU_DIST_ROOT}/include \
-DUSE_VENDOR_BLAS -fopenmp  -std=c99 -O3 -DPRNTlevel=1 -DDEBUGlevel=0 -fPIE \
-o dcreate_matrix.c.o -c dcreate_matrix.c

#mpicc 
${TEST_CC_MPI} \
-I${SUPERLU_DIST_ROOT}/include \
-DUSE_VENDOR_BLAS -fopenmp -std=c99 -O3 -DPRNTlevel=1 -DDEBUGlevel=0 -fPIE \
-o pdtest.c.o -c pdtest.c

#mpicxx 
${TEST_CXX_MPI} \
-fopenmp -std=c++11 -rdynamic -O3 \
pdtest.c.o dcreate_matrix.c.o pdcompute_resid.c.o -o pdtest \
-Wl,-rpath,${OPENBLAS_ROOT}/lib:${PARMETIS_ROOT}/lib:${METIS_ROOT}/lib \
${SUPERLU_DIST_ROOT}/lib/libsuperlu_dist.a \
${OPENBLAS_ROOT}/lib/libopenblas.so \
${PARMETIS_ROOT}/lib/libparmetis.so \
${METIS_ROOT}/lib/libmetis.so \
-lm
