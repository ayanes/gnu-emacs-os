#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2025-2026  Borja Tarraso <borja.tarraso@member.fsf.org>
#
# Run iso-build/freeze-tests.el on the host console (batch Emacs).

set -eu

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SELF_DIR/.." && pwd)
MODULE="${PID1_MODULE_PATH:-$REPO_ROOT/pid1/pid1-module.so}"
STAGE=$(mktemp -d -t geos-freeze-stage.XXXXXX)

cleanup() {
    rm -rf "$STAGE"
}
trap cleanup EXIT INT TERM HUP

if [ ! -f "$MODULE" ]; then
    echo "freeze-test-console: building pid1-module.so" >&2
    make -C "$REPO_ROOT/pid1" module STATIC=0
    MODULE="$REPO_ROOT/pid1/pid1-module.so"
fi

link_as() {
    ln -sf "$1" "$STAGE/$2"
}

# mirror guix's feature-name copies for `(require 'FEATURE)' resolution.
link_as "$REPO_ROOT/emacs-init/buffers/journal.el"       journal-buffer.el
link_as "$REPO_ROOT/emacs-init/buffers/disks.el"         disks-buffer.el
link_as "$REPO_ROOT/emacs-init/buffers/packages.el"     packages-buffer.el
link_as "$REPO_ROOT/emacs-init/buffers/services.el"     services-buffer.el
link_as "$REPO_ROOT/emacs-init/buffers/users.el"        users-buffer.el
link_as "$REPO_ROOT/emacs-init/buffers/install.el"      install-buffer.el
link_as "$REPO_ROOT/emacs-init/buffers/reconfigure.el" reconfigure-buffer.el
link_as "$REPO_ROOT/emacs-init/buffers/audio.el"        audio-buffer.el
link_as "$REPO_ROOT/emacs-init/buffers/processes.el"   processes-buffer.el
link_as "$REPO_ROOT/emacs-init/buffers/network.el"     network-buffer.el
link_as "$REPO_ROOT/emacs-init/buffers/login.el"        login-buffer.el
link_as "$REPO_ROOT/emacs-init/install/disk.el"         install-disk.el
link_as "$REPO_ROOT/emacs-init/install/copy.el"         install-copy.el
link_as "$REPO_ROOT/emacs-init/install/grub.el"         install-grub.el
link_as "$REPO_ROOT/emacs-init/install/mkfs.el"         install-mkfs.el
link_as "$REPO_ROOT/emacs-init/user/userland/uname.el"  userland-uname.el
link_as "$REPO_ROOT/emacs-init/user/userland/audio.el"   userland-audio.el
link_as "$REPO_ROOT/emacs-init/user/userland/journal-client.el" journal-client.el
link_as "$REPO_ROOT/emacs-init/user/userland/services-client.el" services-client.el

export GEOS_PID1=1
export PID1_MODULE_PATH="$MODULE"
export GEOS_KERNEL="${GEOS_KERNEL:-linux}"

echo "freeze-test-console: module=$MODULE kernel=$GEOS_KERNEL" >&2

exec emacs -Q --batch \
    -L "$STAGE" \
    -L "$REPO_ROOT/iso-build" \
    -L "$REPO_ROOT/iso-build/freeze-tests" \
    -L "$REPO_ROOT/emacs-init/core" \
    -L "$REPO_ROOT/emacs-init/buffers" \
    -L "$REPO_ROOT/emacs-init/install" \
    -L "$REPO_ROOT/emacs-init/services" \
    -L "$REPO_ROOT/emacs-init/user" \
    -L "$REPO_ROOT/emacs-init/user/userland" \
    --eval "(define-error 'pid1-error \"PID1 supervision error\")" \
    --eval "(condition-case err (module-load (getenv \"PID1_MODULE_PATH\")) (error (message \"module-load: %S\" err)))" \
    --eval "(require 'panic)" \
    --eval "(require 'port)" \
    --eval "(require 'hostname nil 'noerror)" \
    --eval "(require 'cmdline nil 'noerror)" \
    --eval "(setq freeze-test-console-p t)" \
    --eval "(load-file \"$REPO_ROOT/iso-build/freeze-tests.el\")" \
    --eval "(let ((ok (freeze-test-run-all)) (panic-allow-kill-emacs t)) (kill-emacs (if ok 0 1)))"
