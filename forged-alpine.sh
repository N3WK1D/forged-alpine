#!/bin/sh
set -e
#
# Docker build calls this script to harden the image during build.
#

# Remove world-writable permissions.
# This breaks apps that need to write to /tmp,
# such as ssh-agent.
find / -xdev -type d -not -path /tmp -prune -perm -0002 -exec chmod o-w {} +
find / -xdev -type f -not -path '/tmp/*' -prune -perm -0002 -exec chmod o-w {} +

# Remove unnecessary user accounts.
sed -i -r '/^(abc|root|nobody)/!d' /etc/group
sed -i -r '/^(abc|root|nobody)/!d' /etc/passwd
sed -i -r '/^(abc|root|nobody)/!d' /etc/shadow

# Remove interactive login shell for everybody.
sed -i -r 's|^(.*):[^:]*$|\1:/sbin/nologin|' /etc/passwd

# Disable password login for everybody
while IFS=: read -r username _; do passwd -l "$username"; done < /etc/passwd || true

# Remove existing crontabs, if any.
rm -fr /var/spool/cron \
  /etc/crontabs \
  /etc/periodic

# Remove init scripts since we do not use them.
rm -fr /etc/init.d \
  /lib/rc \
  /etc/conf.d \
  /etc/inittab \
  /etc/runlevels \
  /etc/rc.conf \
  /etc/logrotate.d

# Remove kernel tunables since we do not need them.
rm -fr /etc/sysctl* \
  /etc/modprobe.d \
  /etc/modules \
  /etc/mdev.conf \
  /etc/acpi

# Remove root homedir since we do not need it.
rm -fr /root

# Remove fstab since we do not need it.
rm -f /etc/fstab

sysdirs=(
  '/bin'
  '/etc'
  '/lib'
  '/sbin'
  '/usr'
)

# Remove crufty...
#   /etc/shadow-
#   /etc/passwd-
#   /etc/group-
find ${sysdirs[@]} -xdev -type f -regex '.*-$' -exec rm -f {} +

# Ensure system dirs are owned by root and not writable by anybody else.
find ${sysdirs[@]} -xdev -type d \
  -exec chown root:root {} \; \
  -exec chmod 0755 {} \;

# Remove all suid files.
find ${sysdirs[@]} -xdev -type f -a \( -perm -4000 -o -perm -2000 \) -delete

# Remove programs that could be dangerous.
find ${sysdirs[@]} -xdev \( \
  -name hexdump -o \
  -name chgrp -o \
  -name chmod -o \
  -name chown -o \
  -name ln -o \
  -name od -o \
  -name strings -o \
  -name su \
  -name sudo \
  \) -delete

# Remove broken symlinks (because we removed the targets above).
find ${sysdirs[@]} -xdev -type l -exec test ! -e {} \; -delete

# Remove apk and configs.
find ${sysdirs[@]} -xdev -regex '.*apk.*' -exec rm -fr {} +