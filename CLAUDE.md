# Memory Management Rules (claude-code-memory-guard)

## Memory-Aware Operation Protocol

This project uses automatic memory monitoring via PostToolUse hooks.
When memory warnings appear in tool results, follow these rules strictly.

### On ⚠️ MEMORY WARNING
- Immediately run `/compact` to reduce conversation context
- Switch to partial file reads: always use `offset` and `limit` parameters with Read tool
- Delegate complex subtasks to Task subagents instead of handling inline
- Avoid reading files larger than 500 lines without offset/limit
- Prefer Grep/Glob for searching instead of reading entire files

### On 🚨 MEMORY CRITICAL
- Run `/compact` immediately before any other action
- STOP all file read operations - use only Grep and Glob for targeted searches
- Minimize tool calls to essential operations only
- Complete the current task as quickly as possible
- Recommend session restart to the user after current task completes
- Do NOT start any new large operations (refactoring, multi-file changes, etc.)

### General Memory Hygiene
- Prefer Task subagents for exploration and multi-step research
- Use targeted Grep searches instead of reading entire files
- When reading files, always consider using offset/limit for large files
- Avoid accumulating large amounts of file content in conversation context
