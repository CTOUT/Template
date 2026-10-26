# GitHub Copilot Instructions

## General Standards

- **Language & Spelling**: Enforce UK English (`en-GB`) across all documentation and comments.
- **Security is Foundational (Rule 0)**: Enforce least privilege, secure defaults, and credential hygiene. All GitHub Actions workflows must explicitly declare minimal permissions (e.g. `permissions: contents: read`) to prevent default token privilege inheritance. Never hardcode secrets or absolute local paths.
- **PowerShell Resilience & Modernization**: Enforce PowerShell 7+ syntax and `$ErrorActionPreference = 'Stop'`. Scripts must be idempotent and resilient. When invoking tools across file collections, bind `FileInfo` objects via pipeline (`$files | Invoke-ScriptAnalyzer`) rather than passing arrays to string parameters.
- **Code Style & Formatting**: Follow `.editorconfig`, `.prettierrc`, and `.markdownlint.json` rules. Run Prettier and CSpell before committing.
