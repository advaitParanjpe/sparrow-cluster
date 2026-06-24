#!/usr/bin/env bash
# Run the active milestone in bounded Codex iterations. No commits or pushes occur here.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CURRENT="$ROOT/milestones/current.md"
REPORT="$ROOT/reports/current_milestone_report.md"
RUNS="$ROOT/.codex_runs"
LOCK="$RUNS/milestone.lock"
DEFAULT_MAX_ITERATIONS=5
MAX_ITERATIONS="${MILESTONE_MAX_ITERATIONS:-$DEFAULT_MAX_ITERATIONS}"
NO_PROGRESS_LIMIT=2

usage() {
    echo "usage: $0 [--max-iterations N] [--status]" >&2
}

heading() {
    sed -nE 's/^# (Milestone .*)$/\1/p' "$CURRENT" | head -n 1
}

report_status() {
    local active="$1"
    [[ -f "$REPORT" ]] || { echo "NONE"; return; }
    grep -Fxq "MILESTONE: $active" "$REPORT" || { echo "MISMATCH"; return; }
    if grep -Fxq "STATUS: COMPLETE" "$REPORT"; then echo "COMPLETE"
    elif grep -Fxq "STATUS: BLOCKED" "$REPORT"; then echo "BLOCKED"
    else echo "INCOMPLETE"
    fi
}

snapshot() {
    {
        git -C "$ROOT" diff --no-ext-diff
        git -C "$ROOT" diff --cached --no-ext-diff
        git -C "$ROOT" ls-files --others --exclude-standard
        [[ -f "$REPORT" ]] && cat "$REPORT" || printf '<no report>\n'
    } | cksum
}

status_command() {
    local active
    active="$(heading || true)"
    [[ -n "$active" ]] || active="(no milestone heading)"
    echo "ACTIVE MILESTONE: $active"
    echo "REPORT STATUS: $(report_status "$active")"
}

while (($#)); do
    case "$1" in
        -n|--max-iterations)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            MAX_ITERATIONS="$2"; shift 2 ;;
        --status) status_command; exit 0 ;;
        -h|--help) usage; exit 0 ;;
        *) usage; exit 2 ;;
    esac
done

[[ "$MAX_ITERATIONS" =~ ^[1-9][0-9]*$ ]] || { echo "max iterations must be a positive integer" >&2; exit 2; }
cd "$ROOT"
python3 scripts/check_milestone.py
command -v codex >/dev/null 2>&1 || { echo "milestone runner: codex CLI is not on PATH" >&2; exit 127; }
mkdir -p "$RUNS"

if ! mkdir "$LOCK" 2>/dev/null; then
    if [[ -r "$LOCK/pid" ]] && kill -0 "$(cat "$LOCK/pid")" 2>/dev/null; then
        echo "milestone runner: another runner is active (PID $(cat "$LOCK/pid"))" >&2
        exit 1
    fi
    echo "milestone runner: removing stale lock" >&2
    rm -rf "$LOCK"
    mkdir "$LOCK"
fi
echo "$$" > "$LOCK/pid"
cleanup() { rm -rf "$LOCK"; }
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM
trap 'cleanup; exit 129' HUP

ACTIVE="$(heading)"
[[ -n "$ACTIVE" ]] || { echo "milestone runner: cannot determine active milestone heading" >&2; exit 1; }
STATE="$(report_status "$ACTIVE")"
case "$STATE" in
    COMPLETE) echo "milestone runner: $ACTIVE is already COMPLETE"; exit 0 ;;
    BLOCKED) echo "milestone runner: $ACTIVE is BLOCKED; review its report before retrying" >&2; exit 1 ;;
    MISMATCH)
        stamp="$(date +%Y%m%d-%H%M%S)"
        mv "$REPORT" "$RUNS/stale-report-$stamp.md"
        echo "milestone runner: rotated report for a different milestone" ;;
esac

PROMPT='Read AGENTS.md and milestones/current.md. Continue the current milestone from the repository’s present state. Inspect existing work before editing. Implement only the current milestone; run its required checks, fix failures, and iterate until its completion gate is met or a genuine blocker is documented. Do not start a later milestone. Maintain reports/current_milestone_report.md with the standard concise completion-report fields, including the exact active milestone heading. Do not commit or push.'
no_progress=0
for ((iteration = 1; iteration <= MAX_ITERATIONS; iteration++)); do
    before="$(snapshot)"
    log="$RUNS/milestone-$(date +%Y%m%d-%H%M%S)-iteration-$iteration.log"
    last="$RUNS/milestone-$(date +%Y%m%d-%H%M%S)-iteration-$iteration-last-message.txt"
    echo "milestone runner: iteration $iteration/$MAX_ITERATIONS ($ACTIVE)"
    set +e
    codex \
        --ask-for-approval never \
        --sandbox workspace-write \
        -C "$ROOT" \
        exec \
        -o "$last" \
        "$PROMPT"
    codex_rc=${PIPESTATUS[0]}
    set -e
    state="$(report_status "$ACTIVE")"
    if [[ "$state" == COMPLETE ]]; then
        echo "milestone runner: COMPLETE after iteration $iteration"
        exit 0
    fi
    if [[ "$state" == BLOCKED ]]; then
        echo "milestone runner: BLOCKED after iteration $iteration; see $REPORT" >&2
        exit 1
    fi
    if [[ "$state" == MISMATCH ]]; then
        echo "milestone runner: report milestone does not match '$ACTIVE'" >&2
        exit 1
    fi
    after="$(snapshot)"
    if [[ "$before" == "$after" ]]; then
        ((no_progress += 1))
        echo "milestone runner: no repository or report change ($no_progress/$NO_PROGRESS_LIMIT)" >&2
        if ((no_progress >= NO_PROGRESS_LIMIT)); then
            echo "milestone runner: stopping after repeated no-progress iterations" >&2
            exit 1
        fi
    else
        no_progress=0
    fi
    if ((codex_rc != 0)); then
        echo "milestone runner: Codex exited $codex_rc; retrying while iterations remain" >&2
    fi
done

echo "milestone runner: iteration limit ($MAX_ITERATIONS) reached without COMPLETE or BLOCKED" >&2
exit 1
