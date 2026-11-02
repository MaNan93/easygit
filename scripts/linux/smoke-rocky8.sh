#!/usr/bin/env bash
set -euo pipefail
dnf -y install epel-release
dnf -y install git xorg-x11-server-Xvfb xorg-x11-xauth dbus-x11 xdotool dejavu-sans-fonts
useradd -m easygit-test
mkdir -p /opt/test
tar -xf /work/out/easygit-linux-x86_64.tar.gz -C /opt/test
chmod -R a+rX /opt/test
runuser -u easygit-test -- dbus-run-session -- xvfb-run -a bash -c '
  set -euo pipefail
  /opt/test/easygit-linux-x86_64/start.sh > /tmp/easygit-smoke.log 2>&1 &
  app_pid=$!
  trap "kill $app_pid 2>/dev/null || true" EXIT
  for i in {1..30}; do
    if ! kill -0 "$app_pid" 2>/dev/null; then
      cat /tmp/easygit-smoke.log
      exit 1
    fi
    if xdotool search --onlyvisible --name easygit; then
      cat /tmp/easygit-smoke.log
      echo "Portable window appeared in clean Rocky Linux 8."
      exit 0
    fi
    sleep 1
  done
  cat /tmp/easygit-smoke.log
  exit 1
'
