#!/bin/bash
# Builds a signed lab-agent RPM and repository metadata.
# Usage: build_repo.sh SPEC_FILE OUTPUT_DIR WORK_DIR
set -euo pipefail
spec=$1; out=$2; work=$3
export GNUPGHOME="$work/gnupg"
mkdir -p "$GNUPGHOME" "$out" "$work/rpmbuild"
chmod 700 "$GNUPGHOME"
uid='Lab Example Packaging <packaging@lab.example.com>'
if ! gpg --batch --list-secret-keys "$uid" >/dev/null 2>&1; then
  gpg --batch --pinentry-mode loopback --passphrase '' --quick-gen-key "$uid" rsa2048 sign never
fi
gpg --batch --armor --export "$uid" > "$out/RPM-GPG-KEY-labexample"
rpmbuild --quiet -bb --define "_topdir $work/rpmbuild" "$spec"
cp "$work"/rpmbuild/RPMS/noarch/lab-agent-*.rpm "$out/"
rpmsign --define "_gpg_name $uid" --define "_gpg_path $GNUPGHOME" \
        --define "_gpg_sign_cmd_extra_args --pinentry-mode loopback --passphrase ''" \
        --addsign "$out"/lab-agent-*.rpm >/dev/null
createrepo_c --quiet "$out"
echo "Repository ready in $out"
