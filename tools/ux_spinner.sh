#!/usr/bin/env zsh
# Clean zsh-compatible spinner with time tracking

start_spinner() {
  SPIN_CHARS=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  i=1
  START_TIME=$(date +%s)
  while true; do
    printf "\r[%s] %s" "${SPIN_CHARS[$i]}" "$1"
    ((i = (i % ${#SPIN_CHARS[@]}) + 1))
    sleep 0.1
  done &
  SPIN_PID=$!
}

stop_spinner() {
  kill -9 $SPIN_PID 2>/dev/null
  wait $SPIN_PID 2>/dev/null
  END_TIME=$(date +%s)
  ELAPSED=$((END_TIME - START_TIME))
  printf "\r✅ %s (took %ss)\n" "$1" "$ELAPSED"
}
