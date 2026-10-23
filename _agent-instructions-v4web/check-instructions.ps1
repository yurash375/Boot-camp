# check-instructions.ps1 — проверка файлов постоянных инструкций агентов для проекта v4web.
# Только чтение, ничего не изменяет.
#
# Запуск:
#   powershell -ExecutionPolicy Bypass -File .\check-instructions.ps1
#   powershell -ExecutionPolicy Bypass -File .\check-instructions.ps1 -Root 'D:\другой\путь'

param(
    [string]$Root = 'D:\Work\Yura\v4web\platform'
)

$ErrorActionPreference = 'Stop'

$targets = @(
    @{ Path = Join-Path $Root 'AGENTS.md'
       Sections = @('## О проекте', '## Соглашения по коду', '## База данных (PostgreSQL)', '## Без явного согласования не делать') },
    @{ Path = Join-Path $Root '.clinerules\project.md'
       Sections = @('## Границы изменений', '## Проверка результата', '## Git') }
)

$failed = 0

foreach ($target in $targets) {
    $path = $target.Path
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host "[SKIP] $path - файла нет"
        continue
    }

    $bytes = [System.IO.File]::ReadAllBytes($path)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    $lines = $text -split "`r?`n"

    $problems = @()

    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $problems += 'есть BOM (нужен UTF-8 без BOM)'
    }
    if ($text -match '\t') {
        $problems += 'есть символы табуляции'
    }
    if (($text.Split('```').Count - 1) % 2 -ne 0) {
        $problems += 'непарные ``` блоки кода'
    }
    if ([string]::IsNullOrWhiteSpace($text)) {
        $problems += 'файл пустой'
    }
    $long = @($lines | Where-Object { $_.Length -gt 120 })
    if ($long.Count -gt 0) {
        $problems += "$($long.Count) строк длиннее 120 символов"
    }
    foreach ($section in $target.Sections) {
        if ($text -notmatch [regex]::Escape($section)) {
            $problems += "нет раздела '$section'"
        }
    }

    if ($problems.Count -eq 0) {
        Write-Host "[OK]   $path ($($lines.Count) строк, UTF-8 без BOM)"
    } else {
        $failed++
        Write-Host "[FAIL] $path"
        foreach ($problem in $problems) {
            Write-Host "       - $problem"
        }
    }
}

Write-Host ''
if ($failed -eq 0) {
    Write-Host 'Все проверки пройдены.'
} else {
    Write-Host "Файлов с проблемами: $failed"
}