#!/usr/bin/env bash
# epf-1 AC1.8 (scope): see scope.sh.
D=$(cd "$(dirname "$0")" && pwd)
exec bash "$D/scope.sh" epf-1 'agents/orchestrator\.md|templates/persona-protocol\.md|CONTEXT\.md|\.claude/wiki/architecture\.md|tests/adapter-protocol-parity\.test\.js|\.claude-plugin/plugin\.json|package\.json|CHANGELOG\.md' mirrors
