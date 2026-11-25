#!/usr/bin/env bash
# Applies one Terragrunt stack, keeping Terraform's output in a file and printing only its
# summary (or its errors, with 12-digit numbers redacted). For CI logs in this public repo.
#
#   scripts/apply-stack.sh <stack under infra/terragrunt/live>   e.g. clusters/main/eks
set -euo pipefail

stack="$1"
log="$(mktemp)"

if terragrunt apply -auto-approve -no-color --non-interactive \
    --working-dir "infra/terragrunt/live/$stack" > "$log" 2>&1; then
  grep -oE 'Apply complete.*' "$log"
else
  grep -E 'Error:' "$log" | sed -E 's/[0-9]{12}/************/g'
  exit 1
fi
