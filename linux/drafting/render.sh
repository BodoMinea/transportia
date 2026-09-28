#!/usr/bin/env bash
# Renders draft screenshots. See README.md.
#
#   linux/drafting/render.sh [--tag TAG] [--out DIR] [draft files...]
#
# With no files, renders every *_draft_test.dart under linux/drafting/.
set -euo pipefail

cd "$(dirname "$0")/../.."

tag="${DRAFT_TAG:-draft}"
out="${DRAFT_OUT:-build/drafts}"
files=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) tag="$2"; shift 2 ;;
    --out) out="$2"; shift 2 ;;
    *) files+=("$1"); shift ;;
  esac
done
if [[ ${#files[@]} -eq 0 ]]; then
  mapfile -t files < <(find linux/drafting -name '*_draft_test.dart' | sort)
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is not on PATH; see 'Getting Flutter' in linux/drafting/README.md" >&2
  exit 1
fi

flutter_root="$(cd "$(dirname "$(readlink -f "$(command -v flutter)")")/.." && pwd)"
mkdir -p "$out"
DRAFT_TAG="$tag" DRAFT_OUT="$(cd "$out" && pwd)" FLUTTER_ROOT="$flutter_root" \
  flutter test "${files[@]}"
echo "Drafts written to $out:"
ls -1 "$out" | grep "^${tag}_" || true
