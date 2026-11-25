#!/usr/bin/env bash
# Applies one Terragrunt stack, keeping Terraform's output in a file and printing only its
# summary, or on failure each error with the lines that explain it (12-digit numbers
# redacted). For CI logs in this public repo.
#
#   scripts/apply-stack.sh <stack under infra/terragrunt/live>   e.g. clusters/main/eks
set -euo pipefail

stack="$1"
log="$(mktemp)"

if terragrunt apply -auto-approve -no-color --non-interactive \
    --working-dir "infra/terragrunt/live/$stack" > "$log" 2>&1; then
  grep -oE 'Apply complete.*' "$log"
else
  # Terraform puts an error's cause on the lines after "Error:"; Terragrunt prefixes each
  # line with the stack's name.
  sed -E 's/^.*terraform: //' "$log" | grep -A8 -E '^.?\s*Error:' \
    | grep -vE 'Encoded authorization failure message' | sed -E 's/[0-9]{12}/************/g'
  exit 1
fi
