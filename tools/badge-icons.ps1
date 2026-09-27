# Draws the 512x512 badge images in assets/badge-icons (one per badge in MilestoneConfig).
# Same style as tools/pass-icons.ps1; Roblox shows badge images cropped to a circle, so
# everything important stays inside it. Run: powershell -ExecutionPolicy Bypass -File tools/badge-icons.ps1
Add-Type -AssemblyName System.Drawing

$fontPath = (Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions\*\content\fonts\FredokaOne-Regular.ttf" | Select-Object -First 1).FullName
$fonts = New-Object System.Drawing.Text.PrivateFontCollection
$fonts.AddFontFile($fontPath)
$family = $fonts.Families[0]
$out = Join-Path $PSScriptRoot "..\assets\badge-icons"
New-Item -ItemType Directory -Force $out | Out-Null
$S = 512

function C([int]$r, [int]$g, [int]$b, [int]$a = 255) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }
function P([float]$x, [float]$y) { New-Object System.Drawing.PointF($x, $y) }
function Gradient-Brush($rect, $top, $bottom) {
    New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $top, $bottom, [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
}

function New-Icon($inner, $outer) {
    $bmp = New-Object System.Drawing.Bitmap($S, $S, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse(-140, -160, $S + 280, $S + 300)
    $brush = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
    $brush.CenterPoint = P 256 210
    $brush.CenterColor = $inner
    $brush.SurroundColors = [System.Drawing.Color[]]@($outer)
    $g.FillRectangle($brush, 0, 0, $S, $S)
    $ray = New-Object System.Drawing.SolidBrush((C 255 255 255 26))
    for ($i = 0; $i -lt 16; $i++) {
        $a1 = [Math]::PI * 2 * $i / 16; $a2 = $a1 + [Math]::PI / 16
        $g.FillPolygon($ray, [System.Drawing.PointF[]]@((P 256 210), (P (256 + 420 * [Math]::Cos($a1)) (210 + 420 * [Math]::Sin($a1))), (P (256 + 420 * [Math]::Cos($a2)) (210 + 420 * [Math]::Sin($a2)))))
    }
    return ,@($bmp, $g)
}

function Draw-Rim($g, $color) {
    $g.DrawEllipse((New-Object System.Drawing.Pen((C 10 12 30 200), 22)), 11, 11, 490, 490)
    $g.DrawEllipse((New-Object System.Drawing.Pen($color, 10)), 13, 13, 486, 486)
}

function Draw-Text($g, [string]$text, [float]$size, [float]$cx, [float]$cy, $top, $bottom, $outline, [float]$outlineWidth) {
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddString($text, $family, 0, $size, (P $cx $cy), $format)
    $shadow = $path.Clone()
    $matrix = New-Object System.Drawing.Drawing2D.Matrix
    $matrix.Translate(0, $size * 0.06)
    $shadow.Transform($matrix)
    $shadowPen = New-Object System.Drawing.Pen((C 0 0 0 110), ($outlineWidth + 6)); $shadowPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.DrawPath($shadowPen, $shadow)
    $pen = New-Object System.Drawing.Pen($outline, $outlineWidth); $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.DrawPath($pen, $path)
    $bounds = $path.GetBounds(); $bounds.Inflate(2, 2)
    $g.FillPath((Gradient-Brush $bounds $top $bottom), $path)
}

function Draw-Basketball($g, [float]$cx, [float]$cy, [float]$r) {
    $rect = New-Object System.Drawing.RectangleF(($cx - $r), ($cy - $r), (2 * $r), (2 * $r))
    $g.FillEllipse((Gradient-Brush $rect (C 255 150 60) (C 200 80 20)), $rect)
    $seam = New-Object System.Drawing.Pen((C 40 20 10), ($r * 0.07))
    $g.DrawEllipse($seam, $rect)
    $g.DrawLine($seam, ($cx - $r), $cy, ($cx + $r), $cy)
    $g.DrawLine($seam, $cx, ($cy - $r), $cx, ($cy + $r))
    $g.DrawArc($seam, ($cx - $r * 2.35), ($cy - $r), ($r * 2), ($r * 2), -48, 96)
    $g.DrawArc($seam, ($cx + $r * 0.35), ($cy - $r), ($r * 2), ($r * 2), 132, 96)
}

function Draw-Sparkle($g, [float]$x, [float]$y, [float]$r) {
    $pts = [System.Drawing.PointF[]]@((P $x ($y - $r)), (P ($x + $r * 0.25) ($y - $r * 0.25)), (P ($x + $r) $y),
        (P ($x + $r * 0.25) ($y + $r * 0.25)), (P $x ($y + $r)), (P ($x - $r * 0.25) ($y + $r * 0.25)),
        (P ($x - $r) $y), (P ($x - $r * 0.25) ($y - $r * 0.25)))
    $g.FillPolygon((New-Object System.Drawing.SolidBrush((C 255 255 230 220))), $pts)
}

function Draw-UpArrow($g, [float]$cx, [float]$top, [float]$w, [float]$h, $light, $deep) {
    $pts = [System.Drawing.PointF[]]@((P $cx $top), (P ($cx + $w / 2) ($top + $h * 0.45)), (P ($cx + $w * 0.2) ($top + $h * 0.45)),
        (P ($cx + $w * 0.2) ($top + $h)), (P ($cx - $w * 0.2) ($top + $h)), (P ($cx - $w * 0.2) ($top + $h * 0.45)), (P ($cx - $w / 2) ($top + $h * 0.45)))
    $pen = New-Object System.Drawing.Pen($ink, 10); $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.DrawPolygon($pen, $pts)
    $g.FillPolygon((Gradient-Brush (New-Object System.Drawing.RectangleF(($cx - $w / 2), $top, $w, $h)) $light $deep), $pts)
}

$gold = C 255 238 130
$goldDeep = C 255 168 20
$ink = C 20 16 40
$white = C 255 255 255

function Save($icon, [string]$name) {
    Draw-Rim $icon[1] $goldDeep
    $icon[0].Save((Join-Path $out $name), [System.Drawing.Imaging.ImageFormat]::Png)
    $icon[1].Dispose(); $icon[0].Dispose()
}

# Welcome
$i = New-Icon (C 90 150 255) (C 16 20 70); $g = $i[1]
Draw-Basketball $g 256 200 112
Draw-Text $g "WELCOME" 66 256 392 $white (C 200 230 255) $ink 12
Draw-Sparkle $g 120 120 20; Draw-Sparkle $g 396 110 14
Save $i "welcome.png"

# First Slam
$i = New-Icon (C 255 140 50) (C 70 14 46); $g = $i[1]
Draw-Basketball $g 256 180 100
Draw-Text $g "FIRST" 76 256 342 $gold $goldDeep $ink 14
Draw-Text $g "SLAM!" 92 256 424 $white (C 255 225 190) $ink 14
Save $i "first-slam.png"

# Vertical milestones
foreach ($v in @(@("100", "hops-100.png", (C 70 210 120), (C 8 40 30)), @("200", "sky-walker-200.png", (C 70 190 255), (C 10 30 80)), @("250", "roof-raiser-250.png", (C 255 110 90), (C 70 10 30)))) {
    $i = New-Icon $v[2] $v[3]; $g = $i[1]
    Draw-UpArrow $g 256 70 150 140 (C 170 255 140) (C 30 190 70)
    Draw-Text $g $v[0] 170 256 300 $gold $goldDeep $ink 20
    Draw-Text $g "VERTICAL" 64 256 420 $white (C 200 235 255) $ink 12
    Save $i $v[1]
}

# Courts
$i = New-Icon (C 80 160 255) (C 10 26 74); $g = $i[1]
Draw-Text $g "HIGH" 104 256 170 $white (C 200 230 255) $ink 16
Draw-Text $g "SCHOOL" 96 256 280 $white (C 200 230 255) $ink 16
Draw-Text $g "VARSITY" 64 256 400 $gold $goldDeep $ink 12
Save $i "varsity.png"

$i = New-Icon (C 170 90 255) (C 30 10 70); $g = $i[1]
Draw-Text $g "COLLEGE" 92 256 200 $white (C 230 210 255) $ink 16
Draw-Text $g "BIG STAGE" 70 256 320 $gold $goldDeep $ink 12
Draw-Sparkle $g 130 400 18; Draw-Sparkle $g 382 400 18
Save $i "big-stage.png"

# Skyline Rooftop: night city silhouette with lit windows.
$i = New-Icon (C 70 60 170) (C 10 8 40); $g = $i[1]
$towers = @(@(96, 70, 190), @(160, 58, 120), @(214, 84, 230), @(290, 62, 150), @(346, 76, 205))
foreach ($t in $towers) {
    $x = $t[0]; $w = $t[1]; $h = $t[2]; $top = 330 - $h
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 20 18 50))), $x, $top, $w, $h)
    $g.DrawRectangle((New-Object System.Drawing.Pen($ink, 4)), $x, $top, $w, $h)
    for ($row = $top + 14; $row -lt 318; $row += 22) {
        for ($col = $x + 10; $col -lt ($x + $w - 12); $col += 18) {
            $color = if ((($row + $col) % 3) -eq 0) { (C 80 230 255) } else { (C 255 214 140) }
            $g.FillRectangle((New-Object System.Drawing.SolidBrush($color)), $col, $row, 8, 10)
        }
    }
}
$g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 60 200))), 90, 328, 332, 8)
Draw-Sparkle $g 130 110 16; Draw-Sparkle $g 400 150 12
Draw-Text $g "SKYLINE" 86 256 404 $white (C 255 190 240) $ink 14
Save $i "skyline.png"

# Rebirth
$i = New-Icon (C 255 100 200) (C 60 10 60); $g = $i[1]
$ring = New-Object System.Drawing.Pen($ink, 34); $g.DrawArc($ring, 156, 76, 200, 200, 200, 290)
$ring = New-Object System.Drawing.Pen($gold, 20); $g.DrawArc($ring, 156, 76, 200, 200, 200, 290)
$tip = [System.Drawing.PointF[]]@((P 160 226), (P 215 231), (P 174 280))
$tipPen = New-Object System.Drawing.Pen($ink, 8); $tipPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$g.DrawPolygon($tipPen, $tip)
$g.FillPolygon((New-Object System.Drawing.SolidBrush($gold)), $tip)
Draw-Text $g "REBIRTH" 84 256 390 $white (C 255 220 245) $ink 14
Save $i "born-again.png"

# Dunk Champion (trophy)
$i = New-Icon (C 255 200 60) (C 80 30 10); $g = $i[1]
$cup = New-Object System.Drawing.Drawing2D.GraphicsPath
$cup.AddArc(166, 60, 180, 190, 0, 180); $cup.CloseFigure()
$cupRect = New-Object System.Drawing.RectangleF(166, 60, 180, 200)
$g.FillPath((New-Object System.Drawing.SolidBrush((C 0 0 0 90))), $cup)
$g.FillPath((Gradient-Brush $cupRect (C 255 238 130) (C 230 145 15)), $cup)
$g.DrawPath((New-Object System.Drawing.Pen($ink, 9)), $cup)
$g.DrawArc((New-Object System.Drawing.Pen($ink, 12)), 120, 90, 80, 90, 90, 180)
$g.DrawArc((New-Object System.Drawing.Pen($ink, 12)), 312, 90, 80, 90, 270, 180)
$g.FillRectangle((New-Object System.Drawing.SolidBrush((C 200 120 10))), 236, 250, 40, 40)
$g.FillRectangle((New-Object System.Drawing.SolidBrush((C 230 145 15))), 196, 286, 120, 26)
$g.DrawRectangle((New-Object System.Drawing.Pen($ink, 6)), 196, 286, 120, 26)
Draw-Basketball $g 256 150 42
Draw-Text $g "CHAMP" 96 256 400 $gold $goldDeep $ink 16
Save $i "dunk-champion.png"

Get-ChildItem $out | Select-Object Name, Length
