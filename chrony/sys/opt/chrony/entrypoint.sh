#!/bin/sh

if [ -d /run/chrony ]; then
  chown -R chrony:chrony /run/chrony
  chmod o-rx /run/chrony
fi

# remove previous pid file if it exist
[[ -f /var/run/chrony/chronyd.pid ]] && rm -f /var/run/chrony/chronyd.pid

exec /usr/sbin/chronyd -u chrony -d -x