# Dispatch mock patterns

Open this when you test a CLI dispatch layer that routes flags to subcommand scripts. One harness covers `exec` calls, subprocess scripts and sourced function calls.

1. Override `exec()` with a bash function that captures invocations:

```bash
exec() { echo "capture: exec $*"; }
```

2. Create mock scripts in a temp directory and point `SCRIPTS` at it:

```bash
MOCK_DIR=$(mktemp -d)
cat > "$MOCK_DIR/start_agent.sh" << 'SCRIPT'
echo "capture: MOCK start_agent.sh $*"
SCRIPT
chmod +x "$MOCK_DIR/start_agent.sh"
SCRIPTS="$MOCK_DIR"
```

3. Resolve placeholder variables before sourcing the harness:

```bash
resolved=$(mktemp)
sed "s|@@AGENT_SANDBOX_REPO@@|$REPO_ROOT|g" \
  "$REPO_ROOT/scripts/agent-sandbox.sh" > "$resolved"
source "$resolved"
rm -f "$resolved"
```

4. Parse captured output by filtering stdout lines with a marker:

```bash
CAPTURED=()
stdout=$(main "$@" 2>/dev/null) || true
while IFS= read -r line; do
  if [[ "$line" == capture:* ]]; then
    CAPTURED+=("${line#capture: }")
  fi
done <<< "$stdout"
```
