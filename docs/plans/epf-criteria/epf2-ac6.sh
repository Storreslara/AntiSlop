#!/usr/bin/env bash
# epf-2 AC2.6 (scope): see scope.sh.
D=$(cd "$(dirname "$0")" && pwd)
exec bash "$D/scope.sh" epf-2 'agents/reviewer\.md|templates/persona-protocol\.md|adapters/codex/agents-md-fragment\.md|adapters/cursor/rules/persona-protocol\.mdc|CONTEXT\.md|tests/adapter-protocol-parity\.test\.js|\.claude-plugin/plugin\.json|package\.json|CHANGELOG\.md' mirrors
