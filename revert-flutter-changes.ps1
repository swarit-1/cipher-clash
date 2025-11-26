# Revert all .withOpacity back to .withValues (modern Flutter uses withValues)
# The IDE has Flutter 3.22+ where withValues is preferred

$files = Get-ChildItem -Path "apps\client\lib\src" -Filter "*.dart" -Recurse

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content

    # Revert .withOpacity(X) back to .withValues(alpha: X)
    $content = $content -replace '\.withOpacity\(([0-9.]+)\)', '.withValues(alpha: $1)'

    # Revert conditional withOpacity back to withValues
    $content = $content -replace '\.withOpacity\((unlocked \? [0-9.]+ : [0-9.]+)\)', '.withValues(alpha: $1)'

    # Revert complex expressions
    $content = $content -replace '\.withOpacity\(([^)]+)\)', '.withValues(alpha: $1)'

    if ($content -ne $originalContent) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        Write-Host "Reverted: $($file.Name)"
    }
}

Write-Host "`nDone! All .withOpacity() reverted to .withValues(alpha:)"
