<#
.SYNOPSIS
    Template-as-Code synchronization script for GitHub repositories.
.DESCRIPTION
    Audits and synchronizes repository documentation, linter configs, GitHub Actions workflows,
    discussion templates, copilot instructions, package.json CI script parity, and cspell settings
    across active CTOUT repositories in d:\Repos\GitHub against the Template repository.
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
$archivedRepos = @('vscode-copilot-sync')

if (-not $TargetRepos -or $TargetRepos.Count -eq 0) {
    $TargetRepos = Get-ChildItem -Path $workspaceRoot -Directory |
        Where-Object {
            $_.Name -ne 'Template' -and
            $_.Name -notin $archivedRepos -and
            $_.Name -ne '.agents' -and
            $_.Name -ne '.vscode' -and
            $_.Name -ne 'scratch' -and
            $_.Name -ne 'docs' -and
            (Test-Path (Join-Path $_.FullName '.git')) -and
            ((git -C $_.FullName remote get-url origin 2>$null) -match 'CTOUT/')
        } |
        Select-Object -ExpandProperty Name
}

Write-Host "=== Template-as-Code Synchronization ===" -ForegroundColor Cyan
Write-Host "Template Source: $templateDir"
Write-Host "Target Repositories ($($TargetRepos.Count)): $($TargetRepos -join ', ')"
if ($DryRun) { Write-Host "[DRY RUN MODE ENABLED]" -ForegroundColor Yellow }
Write-Host ""

# Files to sync unconditionally (linters & editor configs)
$syncConfigs = @(
    ".editorconfig",
    ".gitattributes",
    ".prettierrc",
    ".markdownlint.json",
    ".markdownlintignore"
)

# Baseline docs and ignore files to copy only if missing (preserves project-specific metadata)
$baselineDocs = @(
    ".gitignore",
    ".prettierignore",
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

$templatePrettierIgnore = Get-Content (Join-Path $templateDir ".prettierignore") | Where-Object { $_.Trim() -ne '' }

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

    # 2.1 Merge baseline .prettierignore entries without overwriting stack-specific rules
    $prettierIgnorePath = Join-Path $repoPath ".prettierignore"
    if (Test-Path $prettierIgnorePath) {
        $existingLines = @(Get-Content $prettierIgnorePath)
        $missingLines = @($templatePrettierIgnore | Where-Object { $_ -notin $existingLines })
        if ($missingLines.Count -gt 0) {
            if (-not $DryRun) {
                $updatedLines = $existingLines + $missingLines
                $content = ($updatedLines -join "`n") + "`n"
                [System.IO.File]::WriteAllText($prettierIgnorePath, $content)
            }
            Write-Host "  [MERGE] .prettierignore (+$($missingLines.Count) baseline entries)" -ForegroundColor Gray
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

    # 5.1 Sync GitHub Issue Templates if missing
    $issueTemplates = @(
        ".github/ISSUE_TEMPLATE/config.yml",
        ".github/ISSUE_TEMPLATE/bug_report.yml",
        ".github/ISSUE_TEMPLATE/feature_request.yml"
    )
    foreach ($relPath in $issueTemplates) {
        $src = Join-Path $templateDir $relPath
        $dest = Join-Path $repoPath $relPath
        if ((Test-Path $src) -and (-not (Test-Path $dest))) {
            $destDir = Split-Path -Parent $dest
            if (-not (Test-Path $destDir) -and (-not $DryRun)) {
                New-Item -Path $destDir -ItemType Directory -Force | Out-Null
            }
            if (-not $DryRun) {
                Copy-Item -Path $src -Destination $dest -Force
            }
            Write-Host "  [CREATE] $relPath" -ForegroundColor Cyan
        }
    }

    # 6. Tailored Dependabot configuration (.github/dependabot.yml)
    $hasNpm = Test-Path (Join-Path $repoPath "package.json")
    $hasCsproj = Get-ChildItem -Path $repoPath -Filter "*.csproj" -Recurse -Depth 2 -ErrorAction SilentlyContinue
    $hasDocker = (Test-Path (Join-Path $repoPath "docker-compose.yml")) -or (Test-Path (Join-Path $repoPath "Dockerfile"))

    $blocks = @(
@"
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
"@
    )
    if ($hasNpm) {
        $blocks += @"
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
"@
    }
    if ($hasCsproj) {
        $blocks += @"
  - package-ecosystem: "nuget"
    directory: "/"
    schedule:
      interval: "weekly"
"@
    }
    if ($hasDocker) {
        $blocks += @"
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
"@
    }

    $dependabotYaml = "version: 2`n" + "updates:`n" + ($blocks -join "`n") + "`n"
    $depDest = Join-Path $repoPath ".github/dependabot.yml"
    if (-not $DryRun) {
        [System.IO.File]::WriteAllText($depDest, $dependabotYaml.Replace("`r`n", "`n"))
    }
    Write-Host "  [SYNC TAILORED] .github/dependabot.yml" -ForegroundColor Gray

    # 6.1 Enforce package.json Prettier CI Script Parity
    $pkgPath = Join-Path $repoPath "package.json"
    if (Test-Path $pkgPath) {
        try {
            $pkgRaw = Get-Content $pkgPath -Raw
            $pkgObj = $pkgRaw | ConvertFrom-Json
            if ($pkgObj.scripts) {
                $pkgChanged = $false
                if ($pkgObj.scripts.PSObject.Properties['format'] -and $pkgObj.scripts.format -match 'prettier\s+--write\s+"\*\*/') {
                    $pkgObj.scripts.format = "prettier --write ."
                    $pkgChanged = $true
                }
                if ($pkgObj.scripts.PSObject.Properties['format:check'] -and $pkgObj.scripts.'format:check' -match 'prettier\s+--check\s+"\*\*/') {
                    $pkgObj.scripts.'format:check' = "prettier --check ."
                    $pkgChanged = $true
                }
                if ($pkgChanged) {
                    if (-not $DryRun) {
                        $pkgFormatted = ($pkgObj | ConvertTo-Json -Depth 10).Replace("`r`n", "`n") + "`n"
                        [System.IO.File]::WriteAllText($pkgPath, $pkgFormatted)
                        npx prettier --write "$pkgPath" 2>$null
                    }
                    Write-Host "  [STANDARDIZE] package.json format scripts aligned with CI ('.')" -ForegroundColor Cyan
                }
            }
        } catch {
            Write-Warning "  Failed to inspect package.json for ${repoName}: $_"
        }
    }

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
                $formattedJson = $formattedJson.Replace("`r`n", "`n")
                [System.IO.File]::WriteAllText($cspellPath, $formattedJson + "`n")
                npx prettier --write "$cspellPath" 2>$null
            }
            Write-Host "  [SORT/STANDARDIZE] cspell.json (en-GB, sorted words)" -ForegroundColor Gray
        } catch {
            Write-Warning "  Failed to format cspell.json for ${repoName}: $_"
        }
    }

    # 8. LF Line Ending Normalization for Synced Files
    if (-not $DryRun) {
        $lfFiles = @(
            (Join-Path $repoPath ".github/dependabot.yml"),
            (Join-Path $repoPath "CITATION.cff"),
            (Join-Path $repoPath ".editorconfig"),
            (Join-Path $repoPath ".gitattributes"),
            (Join-Path $repoPath ".prettierrc"),
            (Join-Path $repoPath ".prettierignore"),
            (Join-Path $repoPath ".markdownlint.json"),
            (Join-Path $repoPath ".markdownlintignore")
        )
        foreach ($lfFile in $lfFiles) {
            if (Test-Path $lfFile) {
                $text = [System.IO.File]::ReadAllText($lfFile).Replace("`r`n", "`n")
                [System.IO.File]::WriteAllText($lfFile, $text)
            }
        }
    }

    # 9. Apply Remote GitHub Settings (if -ApplyRemoteSettings flag passed)
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
