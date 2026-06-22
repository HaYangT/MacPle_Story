# Agent Collaboration

This repository is configured for Codex and Claude collaboration through `tap` (`@hua-labs/tap`).

## Shared Workspace

- Shared messages and review artifacts live in `tap-comms/`.
- Local runtime state lives in `.tap-comms/` and is intentionally ignored.
- Local machine config lives in `tap-config.local.json` and pins the tap bridge to the Codex-bundled Node 24 runtime.
- Claude MCP config lives in `.mcp.json` and is local because it contains absolute paths.

## Collaboration Rules

- Use the tap MCP tools when available:
  - `tap_set_name` at session start.
  - `tap_who` to see live agents.
  - `tap_list_unread` to pull pending inbox/review messages.
  - `tap_reply` to send direct replies.
  - `tap_broadcast` for all-agent announcements.
  - `tap_heartbeat` before and after substantial work.
- If MCP is unavailable, read and write markdown files directly under `tap-comms/inbox/`, `tap-comms/reviews/`, `tap-comms/findings/`, `tap-comms/handoff/`, and `tap-comms/retros/`.
- Prefer separate branches or worktrees when handing work between agents.
- Before asking another agent for review, include the goal, branch/worktree, files touched, and verification commands already run.
- Treat cross-agent review as a real code review: prioritize bugs, regressions, security, data loss, and missing tests before style.
- Do not run destructive git operations or broad cleanup without explicit user approval.

## Project Notes

- This is a macOS Swift/SwiftUI project.
- The main Xcode scheme is `MacpleStory`.
- A focused test command used in this repo is:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme MacpleStory -destination 'platform=macOS' -derivedDataPath /private/tmp/MacpleStoryDerivedData -only-testing:MacpleStoryTests
```
