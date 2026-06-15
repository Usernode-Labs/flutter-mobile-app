# Claude Notes

All shared project guidance lives in `AGENTS.md`. Run `bash tool/agent-setup.sh`
once in a fresh clone to activate hooks and repo-local skill adapters.

## MCP Servers

Figma and Dart MCP servers are configured at local scope (not in .mcp.json).
If MCP tools fail, do NOT debug .mcp.json — servers are in ~/.claude.json.
Re-add via: `claude mcp add --transport http <name> <url>`
Never add a "type" field to .mcp.json — schema validation rejects it.
