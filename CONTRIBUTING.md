# Contributing Guidelines

Thank you for contributing to this project!

## Getting Started

1. Fork or clone the repository.
2. Ensure your editor respects `.editorconfig`, `.prettierrc`, and `cspell.json`.
3. Create a descriptive branch for your changes.

## Code & Documentation Standards

- Use UK English (`en-GB`) for spelling; keep custom terms in `cspell.json` sorted alphabetically.
- Ensure all markdown files follow standard heading structures (`.markdownlint.json`).
- Before committing or pushing, run the exact CI validation commands in the repository root:
  - `npx prettier --write .`
  - `npx prettier --check "."`
  - `npx cspell "**"`

## Submitting Pull Requests

1. Keep pull requests focused on a single logical change.
2. Ensure all CI/CD security, spellcheck, and format checks pass (`gh run list --limit 5`).
3. Request review from project maintainers.
