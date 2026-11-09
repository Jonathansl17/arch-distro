#!/usr/bin/env bash
# Runs every experiment (run-all.sh) and uploads evidence/<member>/ to
# EVIDENCE_UPLOAD_URL after EACH experiment and once more at the end, so the
# host gets partial results even if a later experiment hangs.
#   experiments/run-and-send.sh [NAME]   (default: $USER)
set -euo pipefail
source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/upload.sh"
require tar curl

member="${1:-$USER}"   # optional: defaults to the login name

rc=0
RUN_ALL_UPLOAD=1 "$EXP_REPO/experiments/run-all.sh" "$member" || rc=$?
(( rc == 0 )) || warn "run-all exited with $rc, sending what was collected"
upload_evidence "$member" final || die "final upload failed"
ok "evidence sent"
exit "$rc"
