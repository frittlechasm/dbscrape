#!/bin/bash

DBSCRAPE_INSTALL_URL="${DBSCRAPE_INSTALL_URL:-https://github.com/frittlechasm/dbscrape/releases/latest/download/dbscrape}"
sourceLocation="${DBSCRAPE_INSTALL_SOURCE:-$DBSCRAPE_INSTALL_URL}"

function usage() {
  cat <<'USAGE'
Usage: install.sh [--bin-dir DIRECTORY] [--source PATH|URL]

Installs or upgrades dbscrape using the latest GitHub release.
The default directory is $HOME/.local/bin.

Environment:
  DBSCRAPE_INSTALL_SOURCE  Local file or URL to install from
  DBSCRAPE_INSTALL_URL     Default download URL
USAGE
}

function checkDependencies() {
  local dependency
  local missingDependencies=()

  for dependency in curl psql; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
      missingDependencies+=("$dependency")
    fi
  done

  if [ "${#missingDependencies[@]}" -ne 0 ]; then
    echo "Missing required commands: ${missingDependencies[*]}" >&2
    echo "Install them, then rerun this installer." >&2
    return 1
  fi
}

function copySource() {
  local source="$1"
  local destination="$2"

  case "$source" in
    http://*|https://*)
      if ! curl -fsSL "$source" -o "$destination"; then
        echo "Unable to download dbscrape from: $source" >&2
        return 1
      fi
      ;;
    *)
      if [ ! -f "$source" ]; then
        echo "Install source not found: $source" >&2
        return 1
      fi
      if ! cp "$source" "$destination"; then
        echo "Unable to copy install source: $source" >&2
        return 1
      fi
      ;;
  esac
}

function cleanupInstaller() {
  if [ -n "${downloadFile:-}" ] && [ -f "$downloadFile" ]; then
    rm -f "$downloadFile"
  fi
}

if [ -z "${BASH_VERSION:-}" ]; then
  echo "Run this installer with Bash." >&2
  exit 1
fi
if [ "${BASH_VERSINFO[0]}" -lt 3 ] \
  || { [ "${BASH_VERSINFO[0]}" -eq 3 ] && [ "${BASH_VERSINFO[1]}" -lt 2 ]; }; then
  echo "dbscrape requires Bash 3.2 or newer." >&2
  exit 1
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --bin-dir)
      shift
      if [ "$#" -eq 0 ] || [ -z "$1" ]; then
        usage >&2
        exit 1
      fi
      binDir="$1"
      explicitBinDir=1
      ;;
    --source)
      shift
      if [ "$#" -eq 0 ] || [ -z "$1" ]; then
        usage >&2
        exit 1
      fi
      sourceLocation="$1"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if ! checkDependencies; then
  exit 1
fi

if [ -z "${binDir:-}" ]; then
  if [ -z "${HOME:-}" ]; then
    echo "HOME is not set; pass --bin-dir with an absolute directory." >&2
    exit 1
  fi
  binDir="$HOME/.local/bin"
fi
if [ "$binDir" != "/" ]; then
  binDir="${binDir%/}"
fi
case "$binDir" in
  /*) ;;
  *)
    echo "Install directory must be absolute: $binDir" >&2
    exit 1
    ;;
esac
case ":${PATH:-}:" in
  *":$binDir:"*) ;;
  *)
    if [ "${explicitBinDir:-0}" -eq 1 ]; then
      echo "Warning: install directory is not on the current PATH: $binDir" >&2
    else
      echo "Install directory is not on PATH: $binDir" >&2
      echo "Add it to PATH or pass --bin-dir with a directory already on PATH." >&2
      exit 1
    fi
    ;;
esac

downloadFile="$(mktemp "${TMPDIR:-/tmp}/dbscrape.XXXXXX")" || {
  echo "Unable to create a temporary download file" >&2
  exit 1
}
trap cleanupInstaller EXIT

if ! copySource "$sourceLocation" "$downloadFile"; then
  exit 1
fi
if [ ! -s "$downloadFile" ] || ! "$BASH" -n "$downloadFile"; then
  echo "Install source failed validation" >&2
  exit 1
fi

if ! mkdir -p "$binDir"; then
  echo "Unable to create install directory: $binDir" >&2
  exit 1
fi
target="$binDir/dbscrape"
if ! install -m 0755 "$downloadFile" "$target"; then
  echo "Unable to install dbscrape at: $target" >&2
  exit 1
fi
if [ ! -f "$target" ] || [ ! -x "$target" ] || ! "$BASH" -n "$target"; then
  echo "Installed file failed verification: $target" >&2
  exit 1
fi

resolvedCommand="$(command -v dbscrape 2>/dev/null)"
echo "Installed dbscrape at: $target"
if [ "$resolvedCommand" != "$target" ]; then
  echo "Warning: 'dbscrape' currently resolves to: ${resolvedCommand:-not found}" >&2
  echo "Use $target or adjust PATH ordering." >&2
fi
printf "Uninstall with: rm %q\n" "$target"
