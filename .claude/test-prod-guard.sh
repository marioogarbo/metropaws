#!/usr/bin/env bash
# Exercise the PreToolUse guard in .claude/settings.json against realistic
# command shapes. Run from the repo root.
set -u

HOOK=$(python -c "
import json
print(json.load(open('.claude/settings.json'))['hooks']['PreToolUse'][0]['hooks'][0]['command'])
")

check() {
  local expect="$1" label="$2" cmd="$3"
  local payload out verdict
  payload=$(python -c "
import json,sys
print(json.dumps({'tool_name':'Bash','tool_input':{'command':sys.argv[1]}}))
" "$cmd")
  out=$(printf '%s' "$payload" | bash -c "$HOOK")
  if [ -z "$out" ]; then
    verdict="allow"
  else
    verdict=$(printf '%s' "$out" | python -c "
import json,sys
print(json.load(sys.stdin)['hookSpecificOutput']['permissionDecision'])
")
  fi
  if [ "$verdict" = "$expect" ]; then
    printf 'PASS  %-8s %s\n' "$verdict" "$label"
  else
    printf 'FAIL  got=%-8s want=%-8s %s\n' "$verdict" "$expect" "$label"
  fi
}

echo "--- must be DENIED ---"
check deny  "prod seed"          'APP_ENV=prod ./.venv/Scripts/python.exe -m scripts.seed'
check deny  "prod migrate"       'cd backend && APP_ENV=prod python -m scripts.migrate'
check deny  "prod app start"     '.\run.ps1 -Env prod'
check deny  "prod uvicorn"       'APP_ENV=prod python -m uvicorn app.main:app'
check deny  "drop table on prod" 'psql "$PROD" -c "DROP TABLE members"'
check deny  "truncate via .env.prod" 'python x.py --env .env.prod --truncate reimbursements'
check deny  "delete from on prod" 'APP_ENV=prod python -c "delete from payments"'

echo
echo "--- must ASK ---"
check ask   "prod deploy"        'Set-Location backend; .\deploy.ps1 -Env prod'

echo
echo "--- must be ALLOWED (dev + ordinary work) ---"
check allow "dev seed"           'APP_ENV=dev ./.venv/Scripts/python.exe -m scripts.seed'
check allow "dev migrate"        'cd backend && APP_ENV=dev python -m scripts.migrate'
check allow "dev deploy"         'Set-Location backend; .\deploy.ps1 -Env dev'
check allow "run tests"          'cd backend && ./.venv/Scripts/python.exe -m pytest tests/'
check allow "git status"         'git status --short'
check allow "prod READ-ONLY"     'APP_ENV=prod python scratchpad/audit_readonly.py'
check allow "grep for a word"    'grep -rn "migrate" docs/'

echo
echo "--- must be ALLOWED (text that only DISCUSSES prod) ---"
check allow "commit msg heredoc" 'git commit -F - <<EOF
backend: seeds and create_all are dev-only; .env.prod stays untouched
EOF'
check allow "doc write heredoc"  'cat > notes.md <<EOF
Run APP_ENV=prod python -m scripts.migrate only when asked.
EOF'
check deny  "heredoc SQL drop"   'psql "$URL" <<EOF
DROP TABLE members;
EOF'
