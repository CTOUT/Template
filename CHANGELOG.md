# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Baseline `.gitignore` with standard build, IDE, secret, and local AI/Copilot/handoff exclusions.
- Additive `.prettierignore` merging and `package.json` CI script parity enforcement in `sync-template.ps1`.
- Initial project structure and documentation boilerplate.

### Changed

- Updated `sync-template.ps1` to filter for active `CTOUT/*` repositories (excluding third-party clones and archived repos) and prevent overwriting project-specific `CITATION.cff` and `.prettierignore` customisations.
- Strengthened `.github/copilot-instructions.md` and `CONTRIBUTING.md` with exact CI validation commands (`npx prettier --check "."` and `npx cspell "**"`).
