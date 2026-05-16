#!/usr/bin/env bash
# qemu-eval.sh — Boot VeloGuardian DNS v0.6.1 in a throwaway qemu VM.
#
# Downloads a Debian 12 cloud image, uses cloud-init to install the appliance
# via the published v0.6.1 installer tarball on first boot, and forwards the
# dashboard and DNS ports to localhost.
#
# Press Ctrl+A then X to terminate the qemu VM. The cache dir at /tmp/vgdns-eval
# persists between runs (skip the Debian re-download); the per-run working dir
# is cleaned on exit.
#
# Prerequisites:
#   qemu-system-x86_64, qemu-img, curl
#   Linux: genisoimage   OR   macOS: hdiutil
#
# Tested on Debian 12, Ubuntu 24.04, Arch (May 2026), macOS 14 with qemu installed
# via Homebrew.

set -euo pipefail

VGDNS_VERSION="0.6.1"
DEBIAN_RELEASE="bookworm"
DEBIAN_IMG="debian-12-nocloud-amd64.qcow2"
DEBIAN_URL="https://cloud.debian.org/images/cloud/${DEBIAN_RELEASE}/latest/${DEBIAN_IMG}"
VGDNS_TARBALL="veloguardian-dns-${VGDNS_VERSION}-linux-amd64.tar.gz"
VGDNS_URL="https://www.veloguardian.com/downloads/${VGDNS_TARBALL}"

CACHE_DIR="/tmp/vgdns-eval"
WORK_DIR=$(mktemp -d -t vgdns-eval-run.XXXXXX)

cleanup() {
  echo
  echo "== Cleaning up working directory =="
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT INT TERM

echo "== Checking prerequisites =="
for cmd in qemu-system-x86_64 qemu-img curl; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "ERROR: required command not found: ${cmd}" >&2
    echo "Install with your package manager (apt, brew, pacman, etc.)." >&2
    exit 1
  fi
done

case "$(uname -s)" in
  Linux)
    if ! command -v genisoimage >/dev/null 2>&1; then
      echo "ERROR: genisoimage not found. Install with 'sudo apt install genisoimage'." >&2
      exit 1
    fi
    MKISO_CMD="genisoimage -output ${WORK_DIR}/seed.iso -volid cidata -joliet -rock ${WORK_DIR}/cidata"
    ;;
  Darwin)
    if ! command -v hdiutil >/dev/null 2>&1; then
      echo "ERROR: hdiutil not found (macOS shipped tool is missing — that's unexpected)." >&2
      exit 1
    fi
    MKISO_CMD="hdiutil makehybrid -o ${WORK_DIR}/seed.iso -hfs -joliet -iso -default-volume-name cidata ${WORK_DIR}/cidata"
    ;;
  *)
    echo "ERROR: unsupported OS $(uname -s). Linux and macOS only." >&2
    exit 1
    ;;
esac

echo "== Preparing cache directory ${CACHE_DIR} =="
mkdir -p "${CACHE_DIR}"

if [ ! -f "${CACHE_DIR}/${DEBIAN_IMG}" ]; then
  echo "== Downloading Debian 12 cloud image (~250 MB, one-time) =="
  curl --fail --location --progress-bar -o "${CACHE_DIR}/${DEBIAN_IMG}" "${DEBIAN_URL}"
else
  echo "== Debian image already cached =="
fi

echo "== Copying base image to per-run disk =="
cp "${CACHE_DIR}/${DEBIAN_IMG}" "${WORK_DIR}/disk.qcow2"
qemu-img resize "${WORK_DIR}/disk.qcow2" 8G >/dev/null

echo "== Generating cloud-init seed =="
mkdir -p "${WORK_DIR}/cidata"
cat > "${WORK_DIR}/cidata/meta-data" <<'EOF'
instance-id: vgdns-eval
local-hostname: vgdns-eval
EOF

cat > "${WORK_DIR}/cidata/user-data" <<EOF
#cloud-config
hostname: vgdns-eval
manage_etc_hosts: true
ssh_pwauth: false
disable_root: false
chpasswd:
  expire: false
  users:
    - name: root
      password: vgdns-eval
      type: text
package_update: true
package_upgrade: false
packages:
  - curl
  - ca-certificates
runcmd:
  - [ bash, -c, "curl -fsSL ${VGDNS_URL} -o /root/${VGDNS_TARBALL}" ]
  - [ bash, -c, "cd /root && tar -xzf ${VGDNS_TARBALL}" ]
  - [ bash, -c, "cd /root/veloguardian-dns-${VGDNS_VERSION} && yes | ./install.sh || true" ]
  - [ bash, -c, "systemctl enable --now vgdns.service" ]
final_message: "VeloGuardian DNS eval VM ready. Open http://localhost:8080/ on the host."
EOF

eval "${MKISO_CMD}" >/dev/null 2>&1

echo
echo "============================================================"
echo "  Starting qemu — VM will boot and install the appliance."
echo "  This takes 1-3 minutes on first run."
echo
echo "  Once cloud-init finishes (look for the 'eval VM ready'"
echo "  message in the console), open:"
echo
echo "    http://localhost:8080/    (dashboard)"
echo "    dig @127.0.0.1 -p 5353 example.com    (DNS query)"
echo
echo "  Default login: admin / admin"
echo "  Root login on VM console: root / vgdns-eval"
echo
echo "  Press Ctrl+A then X to shut down the VM."
echo "============================================================"
echo

exec qemu-system-x86_64 \
  -m 2048 \
  -smp 2 \
  -drive "file=${WORK_DIR}/disk.qcow2,if=virtio" \
  -drive "file=${WORK_DIR}/seed.iso,if=virtio,format=raw" \
  -nic "user,hostfwd=tcp::8080-:8080,hostfwd=udp::5353-:53,hostfwd=tcp::5353-:53" \
  -nographic \
  -enable-kvm 2>/dev/null \
  || exec qemu-system-x86_64 \
       -m 2048 \
       -smp 2 \
       -drive "file=${WORK_DIR}/disk.qcow2,if=virtio" \
       -drive "file=${WORK_DIR}/seed.iso,if=virtio,format=raw" \
       -nic "user,hostfwd=tcp::8080-:8080,hostfwd=udp::5353-:53,hostfwd=tcp::5353-:53" \
       -nographic
