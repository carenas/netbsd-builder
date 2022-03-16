#!/bin/bash

set -euxo pipefail

OS_VERSION="${1-9.2}"
ARCHITECTURE="${2-x86-64}"
shift 2 || true

# rm -rf packer_cache

rm -rf output
packer build \
  -var-file "var_files/common.pkrvars.hcl" \
  -var-file "var_files/$ARCHITECTURE.pkrvars.hcl" \
  -var-file "var_files/$OS_VERSION/common.pkrvars.hcl" \
  -var-file "var_files/$OS_VERSION/$ARCHITECTURE.pkrvars.hcl" \
  "$@" \
  netbsd.pkr.hcl
