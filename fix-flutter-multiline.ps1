# Fix multiline withValues in Flutter files
$files = @(
    "apps\client\lib\src\features\game\enhanced_game_screen.dart"
)

foreach ($filePath in $files) {
    $content = Get-Content $filePath -Raw

    # Replace multiline withValues patterns
    $content = $content -replace '\.withValues\(\s*alpha:\s*([^\)]+)\s*\)', '.withOpacity($1)'

    Set-Content -Path $filePath -Value $content -NoNewline
    Write-Host "Fixed multiline in: $filePath"
}

Write-Host "`nDone!"
