#!/bin/bash

set -eux
set -o pipefail

readonly rkt_image=schu/stage1-kvm-linux-4.9.4
docker pull "${rkt_image}"
readonly container_id=$(docker run -d ${rkt_image} /bin/false 2>/dev/null || true)
docker export -o rkt.tgz "${container_id}"
mkdir -p rkt
tar -xf rkt.tgz -C rkt/

# Pre-fetch stage1 dependency due to rkt#2241
# https://github.com/coreos/rkt/issues/2241
sudo ./rkt/rkt image fetch --insecure-options=image coreos.com/rkt/stage1-kvm:1.22.0

sudo timeout --foreground --kill-after=10 5m \
  ./rkt/rkt \
  run --interactive \
  --uuid-file-save=./rkt-uuid \
  --insecure-options=image,all-run \
  --dns=8.8.8.8 \
  --stage1-path=./rkt/stage1-kvm-linux-4.9.4.aci \
  --volume=gobpf,kind=host,source=$PWD \
  docker://schu/gobpf-ci \
  --mount=volume=gobpf,target=/go/src/github.com/iovisor/gobpf \
  --environment=GOPATH=/go \
  --exec=/bin/sh -- -c \
    'cd /go/src/github.com/iovisor/gobpf ; \
      mount -t tmpfs tmpfs /tmp ; \
      mount -t debugfs debugfs /sys/kernel/debug/ ; \
      go test -tags integration -v ./...'

test_status=$(sudo ./rkt/rkt status $(<rkt-uuid) | awk '/app-/{split($0,a,"=")} END{print a[2]}')
exit $test_status
