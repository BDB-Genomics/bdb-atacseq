#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DEFAULT_CORES="${ATACSEQ_CORES:-4}"
CORES="${DEFAULT_CORES}"
CONFIG_FILE="${REPO_ROOT}/config.yaml"
SNAKEFILE="${REPO_ROOT}/Snakefile"
LOG_FILE="${REPO_ROOT}/pipeline.log"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-${REPO_ROOT}/.cache}"
USE_CONDA=1
DRY_RUN=0
RERUN_INCOMPLETE=1
KEEP_GOING=0
UNLOCK=0

EXTRA_ARGS=()

usage() {
    cat <<'EOF'
Usage: scripts/run_pipeline.sh [options] [-- <extra snakemake args>]

Run the ATAC-seq Snakemake pipeline from the repository root.

Options:
  -c, --cores N           Number of cores to use (default: 4 or $ATACSEQ_CORES)
  -f, --config PATH       Config file to use (default: config.yaml)
  -s, --snakefile PATH    Snakefile to use (default: Snakefile)
  -l, --log PATH          Log file path (default: pipeline.log)
  -n, --dry-run           Build the DAG without executing jobs
  --no-use-conda          Do not pass --use-conda to Snakemake
  --keep-going            Continue after independent job failures
  --no-rerun-incomplete  Do not pass --rerun-incomplete
  --unlock               Unlock the working directory and exit
  -h, --help             Show this help message

Examples:
  scripts/run_pipeline.sh
  scripts/run_pipeline.sh --cores 8 --dry-run
  scripts/run_pipeline.sh --config configs/test.yaml -- --printshellcmds
EOF
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

require_file() {
    local file_path="$1"
    local label="$2"
    [[ -f "${file_path}" ]] || fail "${label} not found: ${file_path}"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

detect_runner() {
    if command_exists snakemake; then
        SNAKEMAKE_CMD=(snakemake)
        return
    fi

    if command_exists conda; then
        if conda run -n snakemake_runner snakemake --version >/dev/null 2>&1; then
            SNAKEMAKE_CMD=(conda run --no-capture-output -n snakemake_runner snakemake)
            return
        fi
    fi

    fail "snakemake is not available on PATH and Conda env 'snakemake_runner' could not be used."
}

detect_python() {
    if command_exists python3; then
        PYTHON_CMD=(python3)
        return
    fi

    if command_exists python; then
        PYTHON_CMD=(python)
        return
    fi

    if command_exists conda; then
        if conda run -n snakemake_runner python --version >/dev/null 2>&1; then
            PYTHON_CMD=(conda run --no-capture-output -n snakemake_runner python)
            return
        fi
    fi

    fail "Python is not available on PATH and Conda env 'snakemake_runner' could not be used."
}

while (($# > 0)); do
    case "$1" in
        -c|--cores)
            [[ $# -ge 2 ]] || fail "Missing value for $1"
            CORES="$2"
            shift 2
            ;;
        -f|--config)
            [[ $# -ge 2 ]] || fail "Missing value for $1"
            CONFIG_FILE="$2"
            shift 2
            ;;
        -s|--snakefile)
            [[ $# -ge 2 ]] || fail "Missing value for $1"
            SNAKEFILE="$2"
            shift 2
            ;;
        -l|--log)
            [[ $# -ge 2 ]] || fail "Missing value for $1"
            LOG_FILE="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=1
            shift
            ;;
        --no-use-conda)
            USE_CONDA=0
            shift
            ;;
        --keep-going)
            KEEP_GOING=1
            shift
            ;;
        --no-rerun-incomplete)
            RERUN_INCOMPLETE=0
            shift
            ;;
        --unlock)
            UNLOCK=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            EXTRA_ARGS+=("$@")
            break
            ;;
        *)
            fail "Unknown option: $1"
            ;;
    esac
done

[[ "${CORES}" =~ ^[1-9][0-9]*$ ]] || fail "--cores must be a positive integer."

CONFIG_FILE="$(realpath -m "${CONFIG_FILE}")"
SNAKEFILE="$(realpath -m "${SNAKEFILE}")"
LOG_FILE="$(realpath -m "${LOG_FILE}")"

require_file "${CONFIG_FILE}" "Config file"
require_file "${SNAKEFILE}" "Snakefile"
require_file "${REPO_ROOT}/rules/scripts/validate_config.py" "Config validator"

mkdir -p "$(dirname "${LOG_FILE}")"
mkdir -p "${XDG_CACHE_HOME}"

detect_runner
detect_python

cd "${REPO_ROOT}"

export XDG_CACHE_HOME

echo "Validating config: ${CONFIG_FILE}"
"${PYTHON_CMD[@]}" "${REPO_ROOT}/rules/scripts/validate_config.py" "${CONFIG_FILE}"

SNAKEMAKE_ARGS=(
    --snakefile "${SNAKEFILE}"
    --configfile "${CONFIG_FILE}"
    --cores "${CORES}"
)

if (( USE_CONDA )); then
    SNAKEMAKE_ARGS+=(--use-conda)
fi

if (( DRY_RUN )); then
    SNAKEMAKE_ARGS+=(--dry-run)
fi

if (( RERUN_INCOMPLETE )); then
    SNAKEMAKE_ARGS+=(--rerun-incomplete)
fi

if (( KEEP_GOING )); then
    SNAKEMAKE_ARGS+=(--keep-going)
fi

if (( UNLOCK )); then
    SNAKEMAKE_ARGS+=(--unlock)
fi

if ((${#EXTRA_ARGS[@]} > 0)); then
    SNAKEMAKE_ARGS+=("${EXTRA_ARGS[@]}")
fi

echo "Running pipeline from: ${REPO_ROOT}"
echo "Log file: ${LOG_FILE}"
echo "Command: ${SNAKEMAKE_CMD[*]} ${SNAKEMAKE_ARGS[*]}"

"${SNAKEMAKE_CMD[@]}" "${SNAKEMAKE_ARGS[@]}" 2>&1 | tee -a "${LOG_FILE}"