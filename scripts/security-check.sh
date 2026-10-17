#!/usr/bin/env bash
#
# Run the same security gates as the CI pipeline, locally, before you push.
#
#   ./scripts/security-check.sh            # run everything
#   SKIP_CONTAINER=1 ./scripts/security-check.sh   # skip the Docker build + Trivy scan
#
# Exit code: 0 if every check passed, 1 if any check failed or a tool is missing.

set -euo pipefail

# Always run from the repo root, wherever the script is called from.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

IMAGE="devsecops-app:local"
BAD_TRIVY_VERSION="0.69.4" # malicious release, see CVE-2026-33634

# Colours only when writing to a terminal.
if [[ -t 1 ]]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; BOLD=""; RESET=""
fi

declare -a RESULTS=()
FAILED=0

header() { printf '\n%s==> %s%s\n' "$BOLD" "$1" "$RESET"; }
pass()   { RESULTS+=("${GREEN}PASS${RESET}  $1"); }
fail()   { RESULTS+=("${RED}FAIL${RESET}  $1"); FAILED=1; }
skip()   { RESULTS+=("${YELLOW}SKIP${RESET}  $1"); }

# Run a check without letting `set -e` abort the script, so every check runs
# and we can print a full summary at the end.
run_check() {
  local name="$1"; shift
  header "$name"
  if "$@"; then pass "$name"; else fail "$name"; fi
}

# --- 1. Pre-flight: are the tools installed? ---------------------------------
header "Checking required tools"
missing=0
tools=(gitleaks terraform checkov)
[[ "${SKIP_CONTAINER:-0}" == "1" ]] || tools+=(docker trivy)
for tool in "${tools[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '  %-10s %s\n' "$tool" "found"
  else
    printf '  %-10s %sMISSING%s\n' "$tool" "$RED" "$RESET"
    missing=1
  fi
done
if [[ "$missing" -eq 1 ]]; then
  echo
  echo "${RED}Install the missing tools, e.g.:${RESET}"
  echo "  brew install gitleaks terraform trivy && pipx install checkov"
  exit 1
fi

if [[ "${SKIP_CONTAINER:-0}" != "1" ]]; then
  trivy_version="$(trivy --version 2>/dev/null | awk '/^Version:/ {print $2; exit}')"
  if [[ "$trivy_version" == "$BAD_TRIVY_VERSION" ]]; then
    echo "${RED}Trivy $BAD_TRIVY_VERSION is a known-malicious release (CVE-2026-33634). Upgrade before scanning.${RESET}"
    exit 1
  fi
fi

# --- 2. Secrets --------------------------------------------------------------
# `gitleaks git` scans every commit in history, not just the current files:
# a secret deleted in a later commit is still leaked.
run_check "Secrets scan (gitleaks, full git history)" \
  gitleaks git --no-banner --redact --exit-code 1 .

# --- 3. Terraform hygiene ----------------------------------------------------
run_check "Terraform format (terraform fmt -check)" \
  terraform -chdir=terraform fmt -check -recursive -diff

# -backend=false: download providers only. No state, no AWS credentials needed.
tf_validate() {
  terraform -chdir=terraform init -backend=false -input=false >/dev/null \
    && terraform -chdir=terraform validate
}
run_check "Terraform validate" tf_validate

# --- 4. IaC security ---------------------------------------------------------
run_check "IaC scan (checkov)" checkov --config-file .checkov.yaml

# --- 5. Container image ------------------------------------------------------
container_scan() {
  if ! docker info >/dev/null 2>&1; then
    echo "${RED}Docker daemon is not running. Start Docker, or set SKIP_CONTAINER=1.${RESET}"
    return 1
  fi
  docker build --quiet --tag "$IMAGE" app \
    && trivy image --quiet --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 "$IMAGE"
}
if [[ "${SKIP_CONTAINER:-0}" == "1" ]]; then
  skip "Container scan (trivy), SKIP_CONTAINER=1"
else
  run_check "Container scan (trivy, HIGH/CRITICAL, fixable only)" container_scan
fi

# --- Summary -----------------------------------------------------------------
header "Summary"
for r in "${RESULTS[@]}"; do echo "  $r"; done
echo
if [[ "$FAILED" -eq 0 ]]; then
  echo "${GREEN}${BOLD}All security checks passed. Safe to push.${RESET}"
else
  echo "${RED}${BOLD}Security checks failed. Fix the issues above before pushing.${RESET}"
fi
exit "$FAILED"
