---
name: audit-config-fixture-listed
description: Test fixture for scripts/audit-config.sh. Not a real agent; never delegate to it.
tools:
  - Read
  - Glob
mcpServers:
  fixture-agent-server:
    command: echo
    args: [fixture-agent-mcp]
---

Fixture agent with a multi-line tools list and its own MCP server.
