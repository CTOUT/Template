<#
.SYNOPSIS
    Template-as-Code synchronization script for GitHub repositories.
.DESCRIPTION
    Audits and synchronizes repository documentation, linter configs, GitHub Actions workflows,
    discussion templates, copilot instructions, and cspell settings across repositories in d:\Repos\GitHub against the Template repository.
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$ApplyRemoteSettings,
    [string[]]$TargetRepos
)

$ErrorActionPreference = 'Stop'
$env:GITHUB_TOKEN = $null
Remove-Item env:GITHUB_TOKEN -ErrorAction SilentlyContinue

$templateDir = $PSScriptRoot
$workspaceRoot = Split-Path -Parent $templateDir

if (-not $TargetRepos -or $TargetRepos.Count -eq 0) {
    $TargetRepos = Get-ChildItem -Path $workspaceRoot -Directory | 
        Where-Object { $_.Name -ne 'Template' -and $_.Name -ne '.agents' -and $_.Name -ne '.vscode' -and $_.Name -ne 'scratch' -and $_.Name -ne 'docs' } |
        Select-Object -ExpandProperty Name
}

Write-Host "=== Template-as-Code Synchronization ===" -ForegroundColor Cyan
Write-Host "Template Source: $templateDir"
Write-Host "Target Repositories ($($TargetRepos.Count)): $($TargetRepos -join ', ')"
if ($DryRun) { Write-Host "[DRY RUN MODE ENABLED]" -ForegroundColor Yellow }
Write-Host ""

# Files to sync unconditionally (linters & workflows)
$syncConfigs = @(
    ".editorconfig",
    ".gitattributes",
    ".prettierrc",
    ".prettierignore",
    ".markdownlint.json",
    ".markdownlintignore"
)

# Baseline docs to copy if missing
$baselineDocs = @(
    "CONTRIBUTING.md",
    "SECURITY.md",
    "CITATION.cff",
    "LICENSE",
    "llms.txt"
)

# Standard workflows and templates to sync
$workflows = @(
    ".github/PULL_REQUEST_TEMPLATE.md",
    ".github/DISCUSSION_TEMPLATE/welcome-and-qa.yml",
    ".github/DISCUSSION_TEMPLATE/ideas-and-feature-requests.yml",
    ".github/workflows/cleanup.yml",
    ".github/workflows/gitleaks.yml",
    ".github/workflows/format.yml",
    ".github/workflows/spellcheck.yml",
    ".github/workflows/ps-analyzer.yml"
)

foreach ($repoName in $TargetRepos) {
    $repoPath = Join-Path $workspaceRoot $repoName
    if (-not (Test-Path $repoPath)) {
        Write-Warning "Repository path not found: $repoPath"
        continue
    }

    Write-Host "Processing [${repoName}]..." -ForegroundColor Green

    # 1. Sync linters and config files
    foreach ($file in $syncConfigs) {
        $src = Join-Path $templateDir $file
        $dest = Join-Path $repoPath $file
        if (Test-Path $src) {
            if (-not $DryRun) {
                Copy-Item -Path $src -Destination $dest -Force
            }
            Write-Host "  [SYNC] $file" -ForegroundColor Gray
        }
    }

    # 2. Sync baseline docs if missing
    foreach ($file in $baselineDocs) {
        $src = Join-Path $templateDir $file
        $dest = Join-Path $repoPath $file
        if ((Test-Path $src) -and (-not (Test-Path $dest))) {
            if (-not $DryRun) {
                Copy-Item -Path $src -Destination $dest -Force
            }
            Write-Host "  [CREATE] $file" -ForegroundColor Cyan
        }
    }

    # 3. Create missing README.md, TODO.md, CHANGELOG.md if absent
    $repoDocs = @("README.md", "TODO.md", "CHANGELOG.md")
    foreach ($file in $repoDocs) {
        $dest = Join-Path $repoPath $file
        if (-not (Test-Path $dest)) {
            $src = Join-Path $templateDir $file
            if (Test-Path $src) {
                if (-not $DryRun) {
                    Copy-Item -Path $src -Destination $dest -Force
                }
                Write-Host "  [CREATE] $file" -ForegroundColor Cyan
            }
        }
    }

    # 4. Sync Copilot instructions if missing
    $copilotSrc = Join-Path $templateDir ".github/copilot-instructions.md"
    $copilotDest = Join-Path $repoPath ".github/copilot-instructions.md"
    if ((Test-Path $copilotSrc) -and (-not (Test-Path $copilotDest))) {
        $destDir = Split-Path -Parent $copilotDest
        if (-not $DryRun) { New-Item -Path $destDir -ItemType Directory -Force | Out-Null }
        if (-not $DryRun) { Copy-Item -Path $copilotSrc -Destination $copilotDest -Force }
        Write-Host "  [CREATE] .github/copilot-instructions.md" -ForegroundColor Cyan
    }

    # 5. Sync GitHub infrastructure (.github/)
    foreach ($relPath in $workflows) {
        $src = Join-Path $templateDir $relPath
        $dest = Join-Path $repoPath $relPath
        $destDir = Split-Path -Parent $dest
        if (-not (Test-Path $destDir)) {
            if (-not $DryRun) {
                New-Item -Path $destDir -ItemType Directory -Force | Out-Null
            }
        }
        if (Test-Path $src) {
            if (-not $DryRun) {
                Copy-Item -Path $src -Destination $dest -Force
            }
            Write-Host "  [SYNC] $relPath" -ForegroundColor Gray
        }
    }

    # 6. Tailored Dependabot configuration (.github/dependabot.yml)
    $hasCsproj = Get-ChildItem -Path $repoPath -Filter "*.csproj" -Recurse -Depth 2
    $hasDocker = (Test-Path (Join-Path $repoPath "docker-compose.yml")) -or (Test-Path (Join-Path $repoPath "Dockerfile"))

    $depEcosystems = @(
        '  - package-ecosystem: "npm"' + "`n" + '    directory: "/"' + "`n" + '    schedule:' + "`n" + '      interval: "weekly"',
        '  - package-ecosystem: "github-actions"' + "`n" + '    directory: "/"' + "`n" + '    schedule:' + "`n" + '      interval: "weekly"'
    )
    if ($hasCsproj) {
        $depEcosystems += '  - package-ecosystem: "nuget"' + "`n" + '    directory: "/"' + "`n" + '    schedule:' + "`n" + '      interval: "weekly"'
    }
    if ($hasDocker) {
        $depEcosystems += '  - package-ecosystem: "docker"' + "`n" + '    directory: "/"' + "`n" + '    schedule:' + "`n" + '      interval: "weekly"'
    }

    $dependabotYaml = "version: 2`nupdates:`n" + ($depEcosystems -join "`n") + "`n"
    $depDest = Join-Path $repoPath ".github/dependabot.yml"
    if (-not $DryRun) {
        Set-Content -Path $depDest -Value $dependabotYaml -Encoding UTF8
    }
    Write-Host "  [SYNC TAILORED] .github/dependabot.yml" -ForegroundColor Gray

    # 7. CSpell Standardization (language en-GB and sorted words)
    $cspellPath = Join-Path $repoPath "cspell.json"
    if (-not (Test-Path $cspellPath)) {
        $srcCspell = Join-Path $templateDir "cspell.json"
        if (-not $DryRun) {
            Copy-Item -Path $srcCspell -Destination $cspellPath -Force
        }
        Write-Host "  [CREATE] cspell.json" -ForegroundColor Cyan
    } else {
        try {
            $jsonRaw = Get-Content $cspellPath -Raw
            $cspellObj = $jsonRaw | ConvertFrom-Json
            $cspellObj.language = "en-GB"
            if ($cspellObj.words) {
                $cspellObj.words = @($cspellObj.words | Sort-Object -Unique)
            }
            if (-not $DryRun) {
                $formattedJson = $cspellObj | ConvertTo-Json -Depth 10
                Set-Content -Path $cspellPath -Value $formattedJson -Encoding UTF8
            }
            Write-Host "  [SORT/STANDARDIZE] cspell.json (en-GB, sorted words)" -ForegroundColor Gray
        } catch {
            Write-Warning "  Failed to format cspell.json for ${repoName}: $_"
        }
    }

    # 8. Apply Remote GitHub Settings (if -ApplyRemoteSettings flag passed)
    if ($ApplyRemoteSettings) {
        Write-Host "  [REMOTE] Applying GitHub remote settings for CTOUT/${repoName}..." -ForegroundColor Yellow
        try {
            gh repo edit "CTOUT/${repoName}" --enable-discussions --enable-issues --delete-branch-on-merge --enable-squash-merge --enable-wiki=false
            Write-Host "  [REMOTE ✅] Settings applied successfully for CTOUT/${repoName}" -ForegroundColor Green
        } catch {
            Write-Warning "  Remote settings failed for CTOUT/${repoName}: $_"
        }
    }
}

Write-Host "`nSynchronization process complete." -ForegroundColor Green
