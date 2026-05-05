#!/usr/bin/env bash
# Batch subcortical segmentation with FSL FIRST (run_first_all) for all
# .nii / .nii.gz files in a directory (non-recursive by default).
#
# Requires: FSL with run_first_all on PATH (or FSLDIR + fsl.sh).
# Docs: https://fsl.fmrib.ox.ac.uk/fsl/docs/structural/first.html

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: batch_run_first_all.sh INPUT_DIR --output-dir DIR --brain-extracted <true|false> [--maxdepth N]

  INPUT_DIR            Directory containing T1-weighted .nii or .nii.gz files
                       (only the top level unless --maxdepth is increased).

  --output-dir DIR     REQUIRED. Root directory for all FIRST outputs (created
                       if missing). -o prefixes mirror paths relative to INPUT_DIR
                       (extensions .nii.gz / .nii stripped). run_first_all still
                       appends _all_fast_firstseg.nii.gz, _all_fast_origsegs.nii.gz,
                       _first.vtk, etc.

  --brain-extracted    REQUIRED. Whether inputs are already brain-extracted
                       (no skull). true|1|yes → pass -b to run_first_all.
                       false|0|no → whole-head T1, do not pass -b.

  --maxdepth N        Passed to find (default: 1 = no subdirectories).

  -h, --help          Show this help.

Check registration: e.g. find under DIR for *_to_std_sub.nii.gz and slicesdir
with MNI152_T1_1mm (see FSL FIRST documentation).
EOF
}

ensure_run_first_all() {
  if command -v run_first_all >/dev/null 2>&1; then
    return 0
  fi
  if [[ -n "${FSLDIR:-}" && -f "${FSLDIR}/etc/fslconf/fsl.sh" ]]; then
    # shellcheck source=/dev/null
    source "${FSLDIR}/etc/fslconf/fsl.sh"
  fi
  if ! command -v run_first_all >/dev/null 2>&1; then
    echo "error: run_first_all not found. Install FSL and/or set FSLDIR and source fsl.sh." >&2
    exit 1
  fi
}

# Print run_first_all -o prefix under OUTPUT_DIR, mirroring path relative to INPUT_DIR.
output_o_prefix() {
  local input_root="$1" output_root="$2" img="$3"
  local idir img_abs rel stem_rel
  idir="$(cd -- "$(dirname -- "$img")" && pwd)" || return 1
  img_abs="${idir}/$(basename -- "$img")"
  rel="${img_abs#"${input_root}/"}"
  if [[ "$rel" == "$img_abs" ]]; then
    echo "error: file not under INPUT_DIR: $img" >&2
    return 1
  fi
  if [[ "$rel" == *.nii.gz ]]; then
    stem_rel="${rel%.nii.gz}"
  elif [[ "$rel" == *.nii ]]; then
    stem_rel="${rel%.nii}"
  else
    stem_rel="$rel"
  fi
  printf '%s/%s\n' "$output_root" "$stem_rel"
}

parse_bool() {
  local v
  v=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$v" in
    true|1|yes) printf 'true\n' ;;
    false|0|no) printf 'false\n' ;;
    *)
      echo "error: invalid --brain-extracted value '$1' (use true or false)" >&2
      exit 1
      ;;
  esac
}

INPUT_DIR=""
OUTPUT_DIR_RAW=""
BRAIN_RAW=""
MAXDEPTH=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --output-dir)
      if [[ $# -lt 2 ]]; then
        echo "error: --output-dir requires a path" >&2
        exit 1
      fi
      OUTPUT_DIR_RAW="$2"
      shift 2
      ;;
    --brain-extracted)
      if [[ $# -lt 2 ]]; then
        echo "error: --brain-extracted requires a value (true or false)" >&2
        exit 1
      fi
      BRAIN_RAW="$2"
      shift 2
      ;;
    --maxdepth)
      if [[ $# -lt 2 ]]; then
        echo "error: --maxdepth requires a number" >&2
        exit 1
      fi
      MAXDEPTH="$2"
      shift 2
      ;;
    -*)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$INPUT_DIR" ]]; then
        echo "error: unexpected extra argument: $1" >&2
        exit 1
      fi
      INPUT_DIR="$1"
      shift
      ;;
  esac
done

if [[ -z "$INPUT_DIR" ]]; then
  echo "error: INPUT_DIR is required" >&2
  usage >&2
  exit 1
fi

if [[ -z "$OUTPUT_DIR_RAW" ]]; then
  echo "error: --output-dir is required" >&2
  usage >&2
  exit 1
fi

if [[ -z "$BRAIN_RAW" ]]; then
  echo "error: --brain-extracted is required (true or false)" >&2
  usage >&2
  exit 1
fi

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "error: not a directory: $INPUT_DIR" >&2
  exit 1
fi

if ! [[ "$MAXDEPTH" =~ ^[0-9]+$ ]]; then
  echo "error: --maxdepth must be a non-negative integer" >&2
  exit 1
fi

BRAIN_EXTRACTED="$(parse_bool "$BRAIN_RAW")"
INPUT_DIR="$(cd -- "$INPUT_DIR" && pwd)"
OUTPUT_DIR="$(mkdir -p -- "$OUTPUT_DIR_RAW" && cd -- "$OUTPUT_DIR_RAW" && pwd)"

ensure_run_first_all

failed=0
while IFS= read -r img; do
  [[ -z "$img" ]] && continue
  out_o="$(output_o_prefix "$INPUT_DIR" "$OUTPUT_DIR" "$img")" || {
    failed=1
    continue
  }
  mkdir -p -- "$(dirname -- "$out_o")"
  echo "---- FIRST: $img -> -o $out_o ----"
  if [[ "$BRAIN_EXTRACTED" == true ]]; then
    if ! run_first_all -b -i "$img" -o "$out_o"; then
      echo "error: run_first_all failed for: $img" >&2
      failed=1
    fi
  else
    if ! run_first_all -i "$img" -o "$out_o"; then
      echo "error: run_first_all failed for: $img" >&2
      failed=1
    fi
  fi
done < <(find "$INPUT_DIR" -maxdepth "$MAXDEPTH" -type f \( -iname '*.nii' -o -iname '*.nii.gz' \) | LC_ALL=C sort)

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi
