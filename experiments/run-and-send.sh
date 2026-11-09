#!/usr/bin/env bash
# Runs every experiment (run-all.sh) and uploads evidence/<member>/ as a
# tarball to EVIDENCE_UPLOAD_URL, so the results reach the host without
# screenshots. The upload happens even if some experiments failed.
#   experiments/run-and-send.sh jonathan
set -euo pipefail
source "$(dirname "$0")/common.sh"
require tar curl

member="${1:?usage: $0 MEMBER_NAME}"
evidence="evidence/$member"

rc=0
"$EXP_REPO/experiments/run-all.sh" "$member" || rc=$?
(( rc == 0 )) || warn "run-all exited with $rc, sending what was collected"

say "Uploading $evidence to $EVIDENCE_UPLOAD_URL"
# A file (not stdin) so curl sends Content-Length instead of chunked data.
tarball="$(mktemp --suffix=.tgz)"
trap 'rm -f "$tarball"' EXIT
tar -C "$EXP_REPO" -czf "$tarball" "$evidence"
curl --fail --show-error --silent -T "$tarball" "$EVIDENCE_UPLOAD_URL/$member.tgz" \
    || die "upload failed: is the receiver running on the host?"
ok "evidence sent"
exit "$rc"
