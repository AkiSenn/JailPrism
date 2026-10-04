# Resize the completed ImageGen edit for Apple's required AppIcon slots.
param([Parameter(Mandatory=$true)][string]$SourceImage)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$destination = Join-Path $PSScriptRoot '../Sources/Assets.xcassets/AppIcon.appiconset'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
$assetRoot = Split-Path -Parent $destination
'{"info":{"author":"xcode","version":1}}' | Set-Content -Encoding utf8 (Join-Path $assetRoot 'Contents.json')
$slots = @(
    @('iphone','20x20',2), @('iphone','20x20',3), @('iphone','29x29',2), @('iphone','29x29',3),
    @('iphone','40x40',2), @('iphone','40x40',3), @('iphone','60x60',2), @('iphone','60x60',3),
    @('ipad','20x20',1), @('ipad','20x20',2), @('ipad','29x29',1), @('ipad','29x29',2),
    @('ipad','40x40',1), @('ipad','40x40',2), @('ipad','76x76',1), @('ipad','76x76',2),
    @('ipad','83.5x83.5',2), @('ios-marketing','1024x1024',1)
)
$inputImage = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $SourceImage).Path)
$items = @()
try {
    foreach ($slot in $slots) {
        $edge = [int]([double]($slot[1].Split('x')[0]) * $slot[2])
        $name = 'Icon-' + $edge + '.png'
        $path = Join-Path $destination $name
        if (!(Test-Path -LiteralPath $path)) {
            $bitmap = New-Object System.Drawing.Bitmap($edge,$edge,[System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.Clear([System.Drawing.Color]::White)
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.DrawImage($inputImage,0,0,$edge,$edge)
                $bitmap.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)
            } finally { $graphics.Dispose(); $bitmap.Dispose() }
        }
        $items += @{idiom=$slot[0]; size=$slot[1]; scale=([string]$slot[2]+'x'); filename=$name}
    }
} finally { $inputImage.Dispose() }
@{images=$items; info=@{author='xcode'; version=1}} | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 (Join-Path $destination 'Contents.json')
