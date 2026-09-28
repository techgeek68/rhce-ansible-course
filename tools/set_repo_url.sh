#!/bin/bash
# Replaces the YOUR_ACCOUNT/YOUR_REPO placeholders with your GitHub repository.
# Works with GNU sed (Linux) and BSD sed (macOS).
# Usage (from the repository root): tools/set_repo_url.sh myaccount rhce-ansible-course
set -euo pipefail
if [ $# -ne 2 ]; then
  echo "Usage: $0 GITHUB_ACCOUNT REPOSITORY_NAME" >&2
  exit 1
fi
cd "$(dirname "$0")/.."
files=$(grep -rl 'YOUR_ACCOUNT/YOUR_REPO' --exclude-dir=.git --exclude=set_repo_url.sh --exclude=MAINTAINING.md . || true)
if [ -z "$files" ]; then
  echo "No placeholders left."
  exit 0
fi
for f in $files; do
  sed -i.bak "s|YOUR_ACCOUNT/YOUR_REPO|$1/$2|g" "$f"
  rm -f "$f.bak"
  echo "updated $f"
done
