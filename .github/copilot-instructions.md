# GitHub Copilot & AI Agent Instructions

## General Standards

- **Language & Spelling**: Enforce UK English (`en-GB`) across all documentation and comments. Keep the `words` array in `cspell.json` sorted alphabetically (case-insensitive) and deduplicated.
- **Security is Foundational (Rule 0)**: Enforce least privilege, secure defaults, and credential hygiene. All GitHub Actions workflows must explicitly declare minimal permissions (e.g. `permissions: contents: read`) to prevent default token privilege inheritance. Never hardcode secrets or absolute local paths.
- **PowerShell Resilience & Modernization**: Enforce PowerShell 7+ syntax and `$ErrorActionPreference = 'Stop'`. Scripts must be idempotent and resilient. When invoking tools across file collections, bind `FileInfo` objects via pipeline (`$files | Invoke-ScriptAnalyzer`) rather than passing arrays to string parameters.
- **Mandatory Pre-Commit & Post-Push CI Gate**:
  - Follow `.editorconfig`, `.prettierrc`, and `.markdownlint.json` rules.
  - Before **every** `git commit` or `git push` (including documentation-only or YAML updates), run `npx prettier --write .`, `npx prettier --check "."`, and `npx cspell "**"` in the repository root so local validation matches `.github/workflows/*.yml` verbatim.
  - Avoid narrow `**/*.{...}` globs in `package.json` format scripts, as Prettier 3 skips dot-directories (`.github/`, `.kiro/`, `.agents/`) when given glob patterns instead of `.`.
  - If a repository ships its own agent or skill definitions (`.github/agents/`, `.github/skills/`, `.agents/`, `.kiro/`), explicitly un-ignore them with `!` rules in `.gitignore` to override host global gitignore rules.
  - After pushing, run `gh run list --limit 5` to confirm all remote GitHub Actions workflows succeed.
