param([string]$Root)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$fontCollection = New-Object System.Drawing.Text.PrivateFontCollection
$fontCollection.AddFontFile((Join-Path $Root 'assets\Hind-Bold.ttf'))
$fontCollection.AddFontFile((Join-Path $Root 'assets\Hind-Regular.ttf'))
$jobs = Get-Content -LiteralPath (Join-Path $Root 'work\text_jobs.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($job in $jobs) {
    $bitmap = New-Object System.Drawing.Bitmap([int]$job.width, [int]$job.height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    foreach ($item in $job.items) {
        $style = if ($item.bold) {[System.Drawing.FontStyle]::Bold} else {[System.Drawing.FontStyle]::Regular}
        $family = if ($item.hindi) {$fontCollection.Families[0]} else {New-Object System.Drawing.FontFamily('Segoe UI')}
        $font = New-Object System.Drawing.Font($family, [single]$item.size, $style, [System.Drawing.GraphicsUnit]::Pixel)
        $brush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($item.color))
        $graphics.DrawString([string]$item.text,$font,$brush,[single]$item.x,[single]$item.y,[System.Drawing.StringFormat]::GenericTypographic)
        $font.Dispose()
        $brush.Dispose()
    }
    $bitmap.Save([string]$job.output,[System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
}
$fontCollection.Dispose()
