# Repository Template

Canonical "Template as Code" repository serving as the single source of truth for repository structure, configuration files, linting standards, and GitHub Actions workflows across all project repositories.

## Overview

This repository establishes the standardized baseline for:

- Repository documentation and legal/compliance metadata.
- Code formatting, editor settings, `.gitignore` hygiene, and spell checking (`en-GB`).
- GitHub Actions workflows for security scanning, Dependabot, PowerShell linting, and artifact retention cleanup.
- Automated synchronization via `sync-template.ps1`.

## Structure

```text
├── .editorconfig
├── .gitattributes
├── .gitignore
├── .prettierrc
├── .prettierignore
├── .markdownlint.json
├── .markdownlintignore
├── cspell.json
├── LICENSE
├── SECURITY.md
├── CONTRIBUTING.md
├── CITATION.cff
├── CHANGELOG.md
├── TODO.md
├── llms.txt
├── welcome-discussion.md
├── .github/
│   ├── copilot-instructions.md
│   ├── dependabot.yml
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── DISCUSSION_TEMPLATE/
│   │   ├── ideas-and-feature-requests.yml
│   │   └── welcome-and-qa.yml
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml
│   │   ├── config.yml
│   │   └── feature_request.yml
│   └── workflows/
│       ├── cleanup.yml
│       ├── format.yml
│       ├── gitleaks.yml
│       ├── ps-analyzer.yml
│       └── spellcheck.yml
└── sync-template.ps1
```

## Usage

Run the synchronization script to audit and apply template standards to target repositories:

```powershell
./sync-template.ps1 -DryRun
./sync-template.ps1
```
