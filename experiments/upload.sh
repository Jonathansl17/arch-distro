# shellcheck shell=bash
# upload_evidence MEMBER LABEL -> sends evidence/MEMBER/ as MEMBER-LABEL.tgz
# to EVIDENCE_UPLOAD_URL. Returns non-zero (does not exit) if the host
# receiver is unreachable, so a long run keeps going. Requires common.sh.

upload_evidence() {
    local member="$1" label="$2" tarball rc=0
    # A file (not stdin) so curl sends Content-Length instead of chunked data.
    tarball="$(mktemp --suffix=.tgz)"
    tar -C "$EXP_REPO" -czf "$tarball" "evidence/$member" \
        && curl --fail --show-error --silent -T "$tarball" \
            "$EVIDENCE_UPLOAD_URL/$member-$label.tgz" \
        || rc=$?
    rm -f "$tarball"
    (( rc == 0 )) || warn "upload of $label failed (receiver on the host down?)"
    return "$rc"
}
