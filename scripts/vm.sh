#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(dirname "$0")")"

# configuration
declare -ra TCP_PORTS=(19521:19521 10443:443 10080:80 10022:22)
declare -ra UDP_PORTS=()
readonly ROOT_DISK='./virtual-machine/root.qcow2'
readonly ROOT_SIZE='40G'

# parse args until positional
args="$(getopt -l install:,help -o i:h -- "$@")"
eval set -- "$args"

installer=''
while [[ "$1" != '--' ]]; do
  case "$1" in
    -i | --install ) shift; installer="$1";;
    -h | --help    ) echo 'usage: vm.sh [-i|--install INSTALLER] [-h|--help]'; exit;;
  esac; shift
done; shift

# ensure disk image exists
mkdir -p "$(dirname "$ROOT_DISK")"
[[ -f "$ROOT_DISK" ]] || qemu-img create -f qcow2 "$ROOT_DISK" "$ROOT_SIZE"

# assemble network arguments including port forwardings
net="passt,model=virtio-net-pci"

host_ipv4="$(ip route get 9.9.9.9 | sed -n 's/.* src \([^ ]\+\).*/\1/p')"
if [[ -n "$host_ipv4" ]]; then
  vm_ipv4="${host_ipv4%.*}.$(( ${host_ipv4##*.} + 1 ))"
  net+=",param=--address,param=$vm_ipv4,param=--map-host-loopback,param=$host_ipv4"
fi

host_ipv6="$(ip -6 route get 2620:fe::fe | sed -n 's/.* src \([^ ]\+\).*/\1/p')"
if [[ -n "$host_ipv6" ]]; then
  vm_ipv6="${host_ipv6%:*}:$(printf '%x' $(( 0x${host_ipv6##*:} + 1 )))"
  net+=",param=--address,param=$vm_ipv6,param=--map-host-loopback,param=$host_ipv6"
fi

if (( ${#TCP_PORTS[@]} > 0 ))
then net+=",tcp-ports=$(printf '%s,,' "${TCP_PORTS[@]}")"; net="${net%,,}"; fi

if (( ${#UDP_PORTS[@]} > 0 ))
then net+=",udp-ports=$(printf '%s,,' "${UDP_PORTS[@]}")"; net="${net%,,}"; fi

# assemble arguments and start virtual machine in TTY
args=(
  -name "FCOS" -enable-kvm -cpu host -m 8G -nographic -serial mon:stdio
  -drive "file=${ROOT_DISK},if=virtio" -nic "$net"
)
if [[ -n "$installer" ]]; then args+=(-cdrom "$installer" -boot 'order=c,once=d'); fi
exec qemu-system-x86_64 "${args[@]}" "$@"
