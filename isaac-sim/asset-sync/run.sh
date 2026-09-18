#!/bin/sh
# Mirrors one workr-studio project into the scenes volume on a fixed cycle,
# through the @workr-labs/sync CLI. The CLI owns the mirror end to end: it
# walks the project, diffs against its own manifest, fetches the delta in
# signed batches, verifies each file's digest before renaming it into
# place, and removes what the walk no longer sees. Nothing here repeats
# any of that; this file is the cycle and the Content browser view.
set -eu

: "${WORKR_TOKEN:?service-account bearer token, read-only scope is sufficient}"
: "${PROJECT_ID:?the workr-studio project this instance mirrors}"
# A version belongs here. Resolving the CLI afresh on every container
# restart lets the code that writes into the scenes volume change without
# anything in this repo changing.
SYNC_PKG="@workr-labs/sync${SYNC_VERSION:+@$SYNC_VERSION}"
SYNC_INTERVAL_SECONDS="${SYNC_INTERVAL_SECONDS:-60}"

SCENES_DIR="${SCENES_DIR:-/scenes}"
# The CLI's directory alone. It prunes by diffing its own manifest, so a
# file written here by anything else survives only incidentally -- which
# is why library/ is projected beside it rather than into it.
ASSETS_DIR="$SCENES_DIR/.assets"
LIBRARY_DIR="$SCENES_DIR/library"

# What the Isaac Sim Content browser is pointed at. Renditions share an
# asset's directory in the mirror and are deliberately left out of the
# projection: the browser should list only what is worth opening.
SCENE_EXTS="usd usda usdc usdz"

log() { echo "asset-sync: $*" >&2; }

# A run that could not fetch part of the project is a failed run whatever
# the exit code says, so the --json result's failed list is checked
# alongside it.
run_sync() {
  out="$(mktemp)"
  if ! npx --yes "$SYNC_PKG" sync "$PROJECT_ID" "$ASSETS_DIR" --json >"$out"; then
    rm -f "$out"; return 1
  fi
  failed="$(jq '.failed | length' "$out")"
  if [ "${failed:-0}" -gt 0 ]; then
    jq -r '.failed[] | "asset-sync: failed \(.asset)/\(.slot // "-"): \(.reason)"' "$out" >&2
    rm -f "$out"; return 1
  fi
  rm -f "$out"
}

# Rebuilt whole and swapped in, so a prune upstream cannot leave a
# dangling link behind for the browser to open.
project_library() {
  staging="$SCENES_DIR/.library-staging"
  rm -rf "$staging"
  mkdir -p "$staging"
  # Sorted so that the asset keeping the undecorated name is the same one
  # from run to run; unsorted, a directory-order change silently renames
  # entries in the browser.
  find "$ASSETS_DIR" -type f | sort | while IFS= read -r src; do
    ext="$(printf '%s' "${src##*.}" | tr '[:upper:]' '[:lower:]')"
    case " $SCENE_EXTS " in *" $ext "*) ;; *) continue ;; esac
    name="$(basename "$src")"
    rel="${src#"$ASSETS_DIR"/}"
    if [ -e "$staging/$name" ]; then
      # Two assets in a project can carry the same display name; the
      # asset id is the only part of the path guaranteed unique, so it
      # disambiguates whichever one lands second.
      name="${name%.*} [${rel%%/*}].$ext"
    fi
    # Relative, so a link still resolves in a container that mounts the
    # volume somewhere other than SCENES_DIR.
    ln -s "../.assets/$rel" "$staging/$name"
  done
  chmod 0777 "$staging"
  rm -rf "$LIBRARY_DIR"
  mv "$staging" "$LIBRARY_DIR"
}

# The scenes volume is shared with a container whose user is not known
# ahead of time, and both write to it.
mkdir -p "$ASSETS_DIR"
chmod 0777 "$SCENES_DIR" "$ASSETS_DIR"

# Sleeping after a run rather than on a clock keeps a run that outlasts
# the interval from overlapping the next one: two syncs sharing one
# manifest would each read the other's half-finished state.
while :; do
  if run_sync; then
    project_library
  else
    log "sync failed, library left as it was; retrying in ${SYNC_INTERVAL_SECONDS}s"
  fi
  sleep "$SYNC_INTERVAL_SECONDS"
done
