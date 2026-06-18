#!/bin/sh
# Runtime (s6 cont-init) permission enforcement for the /share bind mount.
#
# /share is mounted at container START (docker-compose: /share:/share), so it
# does NOT exist during image build and anything baked into the image at /share
# is masked by the host mount anyway. This therefore MUST run at runtime, not as
# a Dockerfile RUN step (which fails with "cannot access '/share/github'").
#
# Make the shared GitHub clones group-writable by `staff` — all interactive
# users are created with primary group staff (see add_users.sh) and need to
# pull/edit the shared repos. Best-effort: never block container startup.
if [ -d /share/github ]; then
  chgrp -R staff /share/github 2>/dev/null || true
  chmod -R g+w   /share/github 2>/dev/null || true
fi
