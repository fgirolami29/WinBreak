#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="$(
  sed -n "s/.*WinBreakVersion -Value '\([^']*\)'.*/\1/p" WinBreak.ps1 |
    head -n 1
)"

[[ -n "$VERSION" ]] || {
  echo "ERROR: cannot read WinBreak version from WinBreak.ps1." >&2
  exit 1
}

DIST="$ROOT/dist"
STAGE="$DIST/WinBreak"
ARCHIVE="$DIST/WinBreak-$VERSION.zip"
CHECKSUM="$DIST/WinBreak-$VERSION.sha256"

RUNTIME_FILES=(
  "WinBreak.ps1"
  "Start-WinBreak.cmd"
  "Start-WinBreak-DryRun.cmd"
  "README.md"
  "CHANGELOG.md"
)

rm -rf "$DIST"
mkdir -p "$STAGE"

for file in "${RUNTIME_FILES[@]}"; do
  [[ -f "$ROOT/$file" ]] || {
    echo "ERROR: required release file is missing: $file" >&2
    exit 1
  }

  cp -p "$ROOT/$file" "$STAGE/$file"
done

find "$STAGE" \
  \( \
    -name '.DS_Store' -o \
    -name '._*' -o \
    -name '.gitignore' -o \
    -name '__MACOSX' \
  \) \
  -exec rm -rf {} +

(
  cd "$DIST"
  COPYFILE_DISABLE=1 zip -X -q -r "$(basename "$ARCHIVE")" WinBreak
)

if unzip -Z1 "$ARCHIVE" |
  grep -Eiq '(^|/)(\.git|\.gitignore|\.DS_Store|__MACOSX)(/|$)|(^|/)\._'
then
  echo "ERROR: forbidden files found in release archive." >&2
  unzip -Z1 "$ARCHIVE" >&2
  exit 1
fi

ACTUAL_FILES="$(
  unzip -Z1 "$ARCHIVE" |
    grep -v '/$' |
    sed 's#^WinBreak/##' |
    LC_ALL=C sort
)"

EXPECTED_FILES="$(
  printf '%s\n' "${RUNTIME_FILES[@]}" |
    LC_ALL=C sort
)"

[[ "$ACTUAL_FILES" == "$EXPECTED_FILES" ]] || {
  echo "ERROR: archive content differs from release allowlist." >&2
  echo "EXPECTED:" >&2
  printf '%s\n' "$EXPECTED_FILES" >&2
  echo "ACTUAL:" >&2
  printf '%s\n' "$ACTUAL_FILES" >&2
  exit 1
}

(
  cd "$DIST"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$(basename "$ARCHIVE")" > "$(basename "$CHECKSUM")"
  else
    sha256sum "$(basename "$ARCHIVE")" > "$(basename "$CHECKSUM")"
  fi
)

echo "Created $ARCHIVE"
unzip -l "$ARCHIVE"
cat "$CHECKSUM"
