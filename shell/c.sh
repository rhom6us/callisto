#!/usr/bin/env bash

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: c [flags] [session-id]"
    echo ""
    echo "Flags (combine in any order, no spaces):"
    echo "  o  model opus (default)"
    echo "  s  model sonnet"
    echo "  h  model haiku"
    echo "  p  model opus + plan mode"
    echo "  i  ide"
    echo "  1  effort low"
    echo "  2  effort medium (default)"
    echo "  3  effort high"
    echo "  c  continue"
    echo "  f  fork"
    echo "  r  resume (session-id as next arg, or picker if omitted)"
    echo ""
    echo "Examples:"
    echo "  c           opus, medium"
    echo "  c si3c      sonnet, ide, high, continue"
    echo "  c r abc123  opus, medium, resume abc123"
    exit 0
fi

test_mode=0
if [[ "$1" == "--test" ]]; then
    test_mode=1
    shift
fi

flags="$1"
resume_id="$2"
args=(claude --dangerously-skip-permissions)
has_model=0
has_effort=0
has_resume=0

for (( i=0; i<${#flags}; i++ )); do
    ch="${flags:$i:1}"
    case "$ch" in
        o|O) args+=(--model opus); has_model=1 ;;
        s|S) args+=(--model sonnet); has_model=1 ;;
        h|H) args+=(--model haiku); has_model=1 ;;
        p|P) args+=(--model opus --permission-mode plan); has_model=1 ;;
        i|I) args+=(--ide) ;;
        1)   args+=(--effort low); has_effort=1 ;;
        2)   args+=(--effort medium); has_effort=1 ;;
        3)   args+=(--effort high); has_effort=1 ;;
        c|C) args+=(--continue) ;;
        f|F) args+=(--fork) ;;
        r|R) has_resume=1 ;;
    esac
done

(( has_model == 0 )) && args+=(--model opus)
(( has_effort == 0 )) && args+=(--effort medium)
if (( has_resume == 1 )); then
    if [[ -n "$resume_id" ]]; then
        args+=(--resume "$resume_id")
    else
        args+=(--resume)
    fi
fi

if (( test_mode == 1 )); then
    echo "${args[@]}"
else
    exec "${args[@]}"
fi
