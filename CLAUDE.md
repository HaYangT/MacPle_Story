# Claude Instructions

Read `AGENTS.md` first and follow the shared Codex/Claude collaboration workflow.

This repo uses `tap` (`@hua-labs/tap`) for agent-to-agent messages. When the tap MCP server is available, use it for handoffs, reviews, findings, and replies. If MCP is not available yet, use the markdown files under `tap-comms/` directly.

At session start, call `tap_set_name` with `claude`, then `tap_who` and `tap_list_unread`. Use `tap_reply` for direct replies to Codex.
