#!/bin/bash
for d in `ls`; do
  if [[ -d "${d}" ]]; then (cd "${d}" && ./clean.sh) ; fi
done
