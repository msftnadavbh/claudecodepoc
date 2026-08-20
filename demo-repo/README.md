# Discount Cart Demo

A tiny Python application used to prove that Claude Code can inspect a repository, edit code, and execute a deterministic local test command while inference traverses APIM and Microsoft Foundry.

Run the deterministic tests from this directory. They are expected to fail until the agent fixes the fixture copy:

```bash
python3 -m unittest discover -s tests -v
```

The initial implementation contains one arithmetic bug by design.

From the parent repository, run the full APIM-backed Claude Code smoke workflow with:

```bash
./scripts/run-claude-code-smoke.sh
```

The smoke workflow copies this fixture to a temporary worktree before asking Claude Code to fix the bug, so the checked-out fixture stays unchanged. It obtains gateway credentials outside this directory; the Claude task itself is not allowed to inspect Azure configuration or credentials.
