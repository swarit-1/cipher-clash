# Fix Flutter withValues to withOpacity for Dart 3.0 compatibility
# withValues(alpha:) was introduced in Dart 3.4, withOpacity works in all versions

$files = Get-ChildItem -Path "apps\client\lib\src" -Filter "*.dart" -Recurse

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content

    # Replace .withValues(alpha: X) with .withOpacity(X)
    $content = $content -replace '\.withValues\(alpha:\s*([0-9.]+)\)', '.withOpacity($1)'

    if ($content -ne $originalContent) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        Write-Host "Fixed: $($file.Name)"
    }
}

Write-Host "`nDone! All .withValues(alpha: X) replaced with .withOpacity(X)"
