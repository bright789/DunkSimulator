Add-Type -AssemblyName System.Drawing

$fontPath = (Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions\*\content\fonts\FredokaOne-Regular.ttf" | Select-Object -First 1).FullName
$fonts = New-Object System.Drawing.Text.PrivateFontCollection
$fonts.AddFontFile($fontPath)
$family = $fonts.Families[0]
$out = "C:\Users\brigh\Downloads\DunkSimulator\DunkSimulator\assets\pass-icons"
New-Item -ItemType Directory -Force $out | Out-Null
$S = 512

function C([int]$r, [int]$g, [int]$b, [int]$a = 255) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }
function P([float]$x, [float]$y) { New-Object System.Drawing.PointF($x, $y) }

function New-Icon {
    $bmp = New-Object System.Drawing.Bitmap($S, $S, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    return ,@($bmp, $g)
}

# Radial background glow (Roblox crops pass icons to a circle, so the edges fall away).
function Fill-Background($g, $inner, $outer) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse(-140, -160, $S + 280, $S + 300)
    $brush = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
    $brush.CenterPoint = P 256 220
    $brush.CenterColor = $inner
    $brush.SurroundColors = [System.Drawing.Color[]]@($outer)
    $g.FillRectangle($brush, 0, 0, $S, $S)
}

# Soft sunburst rays behind the art.
function Draw-Rays($g, $color, [int]$count, [float]$cx, [float]$cy) {
    $brush = New-Object System.Drawing.SolidBrush($color)
    for ($i = 0; $i -lt $count; $i++) {
        $a1 = [Math]::PI * 2 * $i / $count
        $a2 = $a1 + [Math]::PI / $count
        $pts = [System.Drawing.PointF[]]@((P $cx $cy),
            (P ($cx + 420 * [Math]::Cos($a1)) ($cy + 420 * [Math]::Sin($a1))),
            (P ($cx + 420 * [Math]::Cos($a2)) ($cy + 420 * [Math]::Sin($a2))))
        $g.FillPolygon($brush, $pts)
    }
}

# Gold rim that becomes the icon's circular border.
function Draw-Rim($g, $color) {
    $pen = New-Object System.Drawing.Pen((C 10 12 30 200), 22)
    $g.DrawEllipse($pen, 11, 11, 490, 490)
    $pen = New-Object System.Drawing.Pen($color, 10)
    $g.DrawEllipse($pen, 13, 13, 486, 486)
}

function Gradient-Brush($rect, $top, $bottom) {
    New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $top, $bottom, [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
}

# Chunky cartoon text: drop shadow, thick dark outline, gradient fill.
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
    $shadowPen = New-Object System.Drawing.Pen((C 0 0 0 110), ($outlineWidth + 6))
    $shadowPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.DrawPath($shadowPen, $shadow)
    $pen = New-Object System.Drawing.Pen($outline, $outlineWidth)
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.DrawPath($pen, $path)
    $bounds = $path.GetBounds()
    $bounds.Inflate(2, 2)
    $g.FillPath((Gradient-Brush $bounds $top $bottom), $path)
}

function Draw-Sparkle($g, [float]$x, [float]$y, [float]$r, $color) {
    $pts = [System.Drawing.PointF[]]@((P $x ($y - $r)), (P ($x + $r * 0.25) ($y - $r * 0.25)), (P ($x + $r) $y),
        (P ($x + $r * 0.25) ($y + $r * 0.25)), (P $x ($y + $r)), (P ($x - $r * 0.25) ($y + $r * 0.25)),
        (P ($x - $r) $y), (P ($x - $r * 0.25) ($y - $r * 0.25)))
    $g.FillPolygon((New-Object System.Drawing.SolidBrush($color)), $pts)
}

function Draw-Basketball($g, [float]$cx, [float]$cy, [float]$r) {
    $rect = New-Object System.Drawing.RectangleF(($cx - $r), ($cy - $r), (2 * $r), (2 * $r))
    $g.FillEllipse((Gradient-Brush $rect (C 255 150 60) (C 200 80 20)), $rect)
    $seam = New-Object System.Drawing.Pen((C 40 20 10), ($r * 0.07))
    $g.DrawEllipse($seam, $rect)
    $g.DrawLine($seam, ($cx - $r), $cy, ($cx + $r), $cy)
    $g.DrawLine($seam, $cx, ($cy - $r), $cx, ($cy + $r))
    # Side seams: arcs of circles centered outside the ball, curving in toward the middle.
    $g.DrawArc($seam, ($cx - $r * 2.35), ($cy - $r), ($r * 2), ($r * 2), -48, 96)
    $g.DrawArc($seam, ($cx + $r * 0.35), ($cy - $r), ($r * 2), ($r * 2), 132, 96)
}

$gold = C 255 238 130
$goldDeep = C 255 168 20
$ink = C 20 16 40

# 1) 2x CASH -----------------------------------------------------------------------------
$icon = New-Icon; $bmp = $icon[0]; $g = $icon[1]
Fill-Background $g (C 60 200 110) (C 8 36 32)
Draw-Rays $g (C 255 255 200 28) 16 256 200
# Gold coin with a $.
$coin = New-Object System.Drawing.RectangleF(151, 70, 210, 210)
$g.FillEllipse((Gradient-Brush $coin (C 255 236 120) (C 235 150 20)), $coin)
$g.DrawEllipse((New-Object System.Drawing.Pen((C 150 90 10), 10)), $coin)
$g.DrawEllipse((New-Object System.Drawing.Pen((C 255 250 200 150), 5)), 173, 92, 166, 166)
Draw-Text $g '$' 150 256 178 (C 200 120 10) (C 150 80 5) (C 255 245 190) 6
Draw-Text $g '2x' 190 256 318 $gold $goldDeep $ink 20
Draw-Text $g 'CASH' 82 256 430 (C 255 255 255) (C 200 255 210) $ink 14
Draw-Sparkle $g 118 150 20 (C 255 255 220 220)
Draw-Sparkle $g 398 116 14 (C 255 255 220 200)
Draw-Rim $g $goldDeep
$bmp.Save("$out\2x-cash.png", [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# 2) VIP ---------------------------------------------------------------------------------
$icon = New-Icon; $bmp = $icon[0]; $g = $icon[1]
Fill-Background $g (C 150 90 255) (C 26 12 64)
Draw-Rays $g (C 255 230 150 30) 16 256 190
# Crown.
$crown = [System.Drawing.PointF[]]@((P 140 262), (P 140 150), (P 198 205), (P 256 110), (P 314 205), (P 372 150), (P 372 262))
$crownRect = New-Object System.Drawing.RectangleF(140, 110, 232, 152)
$g.FillPolygon((Gradient-Brush $crownRect (C 255 238 130) (C 230 145 15)), $crown)
$crownPen = New-Object System.Drawing.Pen($ink, 9); $crownPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$g.DrawPolygon($crownPen, $crown)
$g.FillRectangle((New-Object System.Drawing.SolidBrush((C 200 120 10))), 146, 236, 220, 18)
foreach ($peak in @(@(140, 150), @(256, 110), @(372, 150))) {
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 245 200))), ($peak[0] - 14), ($peak[1] - 14), 28, 28)
    $g.DrawEllipse((New-Object System.Drawing.Pen($ink, 5)), ($peak[0] - 14), ($peak[1] - 14), 28, 28)
}
# Diamond gem on the crown.
$gem = [System.Drawing.PointF[]]@((P 256 176), (P 284 204), (P 256 240), (P 228 204))
$gemRect = New-Object System.Drawing.RectangleF(228, 176, 56, 64)
$g.FillPolygon((Gradient-Brush $gemRect (C 220 250 255) (C 80 200 255)), $gem)
$g.DrawPolygon((New-Object System.Drawing.Pen($ink, 5)), $gem)
Draw-Text $g 'VIP' 168 256 358 $gold $goldDeep $ink 20
Draw-Sparkle $g 110 118 22 (C 255 255 230 230)
Draw-Sparkle $g 404 104 16 (C 200 240 255 230)
Draw-Sparkle $g 420 300 12 (C 255 255 230 200)
Draw-Rim $g $goldDeep
$bmp.Save("$out\vip.png", [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# 3) 2x DAILY REWARDS --------------------------------------------------------------------
$icon = New-Icon; $bmp = $icon[0]; $g = $icon[1]
Fill-Background $g (C 70 175 255) (C 10 26 74)
Draw-Rays $g (C 255 255 255 24) 16 256 210
# Calendar page.
$page = New-Object System.Drawing.Drawing2D.GraphicsPath
$page.AddArc(130, 110, 40, 40, 180, 90); $page.AddArc(342, 110, 40, 40, 270, 90)
$page.AddArc(342, 318, 40, 40, 0, 90); $page.AddArc(130, 318, 40, 40, 90, 90); $page.CloseFigure()
$g.FillPath((New-Object System.Drawing.SolidBrush((C 0 0 0 90))), $page.Clone())
$g.FillPath((New-Object System.Drawing.SolidBrush((C 250 250 255))), $page)
$header = New-Object System.Drawing.Drawing2D.GraphicsPath
$header.AddArc(130, 110, 40, 40, 180, 90); $header.AddArc(342, 110, 40, 40, 270, 90)
$header.AddLine(382, 130, 382, 172); $header.AddLine(382, 172, 130, 172); $header.CloseFigure()
$g.FillPath((Gradient-Brush (New-Object System.Drawing.RectangleF(130, 110, 252, 62)) (C 255 90 90) (C 210 40 50)), $header)
$g.DrawPath((New-Object System.Drawing.Pen($ink, 8)), $page)
foreach ($x in @(196, 316)) {
    $g.FillRectangle((New-Object System.Drawing.SolidBrush($ink)), ($x - 9), 92, 18, 44)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((C 200 205 220))), ($x - 5), 96, 10, 36)
}
Draw-Text $g '2x' 128 256 262 $gold $goldDeep $ink 16
Draw-Text $g 'DAILY' 80 256 428 (C 255 255 255) (C 200 230 255) $ink 14
Draw-Sparkle $g 104 140 18 (C 255 255 230 220)
Draw-Sparkle $g 414 250 14 (C 255 255 230 200)
Draw-Rim $g $goldDeep
$bmp.Save("$out\2x-daily-rewards.png", [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# 4) CASH BOOST (15 MIN) -----------------------------------------------------------------
$icon = New-Icon; $bmp = $icon[0]; $g = $icon[1]
Fill-Background $g (C 255 140 50) (C 70 14 46)
Draw-Rays $g (C 255 240 180 30) 16 256 200
Draw-Basketball $g 256 205 118
# Lightning bolt over the ball.
$bolt = [System.Drawing.PointF[]]@((P 296 52), (P 176 228), (P 250 228), (P 214 364), (P 344 172), (P 268 172), (P 318 52))
$boltRect = New-Object System.Drawing.RectangleF(176, 52, 168, 312)
$boltPen = New-Object System.Drawing.Pen($ink, 12); $boltPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$g.DrawPolygon($boltPen, $bolt)
$g.FillPolygon((Gradient-Brush $boltRect (C 255 250 170) (C 255 180 20)), $bolt)
Draw-Text $g '2x' 66 380 112 $gold $goldDeep $ink 12
Draw-Text $g '15 MIN' 84 256 424 (C 255 255 255) (C 255 225 190) $ink 14
Draw-Sparkle $g 120 118 18 (C 255 255 230 220)
Draw-Rim $g $goldDeep
$bmp.Save("$out\cash-boost-15min.png", [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# 5) AUTO TRAIN ---------------------------------------------------------------------------
$icon = New-Icon; $bmp = $icon[0]; $g = $icon[1]
Fill-Background $g (C 80 220 170) (C 8 40 50)
Draw-Rays $g (C 255 255 220 28) 16 256 200
# Circular arrows around an up arrow: training on repeat.
$ringPen = New-Object System.Drawing.Pen($ink, 30); $g.DrawArc($ringPen, 146, 70, 220, 220, 210, 300)
$ringPen = New-Object System.Drawing.Pen((C 255 238 130), 16); $g.DrawArc($ringPen, 146, 70, 220, 220, 210, 300)
$head = [System.Drawing.PointF[]]@((P 142 128), (P 196 108), (P 180 160))
$g.FillPolygon((New-Object System.Drawing.SolidBrush((C 255 238 130))), $head)
$arrow = [System.Drawing.PointF[]]@((P 256 112), (P 306 172), (P 278 172), (P 278 240), (P 234 240), (P 234 172), (P 206 172))
$arrowPen = New-Object System.Drawing.Pen($ink, 10); $arrowPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$g.DrawPolygon($arrowPen, $arrow)
$g.FillPolygon((Gradient-Brush (New-Object System.Drawing.RectangleF(206, 112, 100, 128)) (C 170 255 140) (C 30 190 70)), $arrow)
Draw-Text $g 'AUTO' 96 256 350 $gold $goldDeep $ink 16
Draw-Text $g 'TRAIN' 78 256 436 (C 255 255 255) (C 200 255 230) $ink 14
Draw-Rim $g $goldDeep
$bmp.Save("$out\auto-train.png", [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# 6) STARTER PACK ------------------------------------------------------------------------
$icon = New-Icon; $bmp = $icon[0]; $g = $icon[1]
Fill-Background $g (C 255 110 160) (C 60 10 60)
Draw-Rays $g (C 255 240 200 30) 16 256 200
# Gift box with a basketball peeking out.
Draw-Basketball $g 256 128 62
$boxRect = New-Object System.Drawing.RectangleF(146, 150, 220, 140)
$g.FillRectangle((Gradient-Brush $boxRect (C 120 90 255) (C 70 40 200)), $boxRect)
$g.DrawRectangle((New-Object System.Drawing.Pen($ink, 9)), 146, 150, 220, 140)
$g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 214 64))), 238, 150, 36, 140)
$lid = New-Object System.Drawing.RectangleF(132, 128, 248, 34)
$g.FillRectangle((Gradient-Brush $lid (C 150 120 255) (C 100 70 230)), $lid)
$g.DrawRectangle((New-Object System.Drawing.Pen($ink, 9)), 132, 128, 248, 34)
$g.FillRectangle((New-Object System.Drawing.SolidBrush((C 255 214 64))), 238, 128, 36, 34)
Draw-Text $g 'STARTER' 76 256 350 $gold $goldDeep $ink 14
Draw-Text $g 'PACK' 88 256 432 (C 255 255 255) (C 255 220 240) $ink 14
Draw-Sparkle $g 120 120 20 (C 255 255 230 220)
Draw-Sparkle $g 400 110 16 (C 255 255 230 220)
Draw-Rim $g $goldDeep
$bmp.Save("$out\starter-pack.png", [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# Hype Crew pass helpers: trading cards, stars and a four-leaf clover.
function Round-Rect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc(($x + $w - $d), $y, $d, $d, 270, 90)
    $path.AddArc(($x + $w - $d), ($y + $h - $d), $d, $d, 0, 90)
    $path.AddArc($x, ($y + $h - $d), $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function Star-Points([float]$cx, [float]$cy, [float]$outer, [float]$inner) {
    $pts = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
    for ($i = 0; $i -lt 10; $i++) {
        $r = if ($i % 2 -eq 0) { $outer } else { $inner }
        $a = -[Math]::PI / 2 + $i * [Math]::PI / 5
        $pts.Add((P ($cx + $r * [Math]::Cos($a)) ($cy + $r * [Math]::Sin($a))))
    }
    return ,($pts.ToArray())
}

$round = [System.Drawing.Drawing2D.LineJoin]::Round

# A Hype Crew trading card: rarity border, glossy face and a big star (or a crew silhouette).
function Draw-Card($g, [float]$cx, [float]$cy, [float]$w, [float]$h, [float]$angle, $border, $top, $bottom, $starTop, $starBottom, [bool]$person) {
    $state = $g.Save()
    $g.TranslateTransform($cx, $cy)
    $g.RotateTransform($angle)
    $shadow = Round-Rect (-$w / 2 + 6) (-$h / 2 + 10) $w $h 18
    $g.FillPath((New-Object System.Drawing.SolidBrush((C 0 0 0 95))), $shadow)
    $card = Round-Rect (-$w / 2) (-$h / 2) $w $h 18
    $rect = New-Object System.Drawing.RectangleF((-$w / 2), (-$h / 2), $w, $h)
    $g.FillPath((Gradient-Brush $rect $top $bottom), $card)
    $inner = Round-Rect (-$w / 2 + 14) (-$h / 2 + 14) ($w - 28) ($h - 28) 10
    $g.FillPath((New-Object System.Drawing.SolidBrush((C 255 255 255 38))), $inner)
    $pen = New-Object System.Drawing.Pen($ink, 12); $pen.LineJoin = $round
    $g.DrawPath($pen, $card)
    $pen2 = New-Object System.Drawing.Pen($border, 7); $pen2.LineJoin = $round
    $g.DrawPath($pen2, $card)
    $symbolPen = New-Object System.Drawing.Pen($ink, 7); $symbolPen.LineJoin = $round
    if ($person) {
        # Crew member silhouette: head and shoulders.
        $headR = $w * 0.19
        $head = New-Object System.Drawing.RectangleF((-$headR), (-$h * 0.3), ($headR * 2), ($headR * 2))
        $body = New-Object System.Drawing.Drawing2D.GraphicsPath
        $body.AddArc((-$w * 0.33), (-$h * 0.02), ($w * 0.66), ($h * 0.5), 180, 180)
        $body.CloseFigure()
        $fillRect = New-Object System.Drawing.RectangleF((-$w / 2), (-$h * 0.3), $w, ($h * 0.55))
        $g.DrawPath($symbolPen, $body)
        $g.FillPath((Gradient-Brush $fillRect $starTop $starBottom), $body)
        $g.DrawEllipse($symbolPen, $head)
        $g.FillEllipse((Gradient-Brush $head $starTop $starBottom), $head)
    } else {
        $star = Star-Points 0 (-4) ($w * 0.33) ($w * 0.145)
        $starRect = New-Object System.Drawing.RectangleF((-$w * 0.33), (-4 - $w * 0.33), ($w * 0.66), ($w * 0.66))
        $g.DrawPolygon($symbolPen, $star)
        $g.FillPolygon((Gradient-Brush $starRect $starTop $starBottom), $star)
    }
    # Glossy highlight across the top-left.
    $gloss = New-Object System.Drawing.Drawing2D.GraphicsPath
    $gloss.AddPolygon([System.Drawing.PointF[]]@((P (-$w / 2 + 16) (-$h / 2 + 16)), (P (-$w / 2 + 46) (-$h / 2 + 16)),
        (P (-$w / 2 + 16) (-$h / 2 + 70))))
    $g.FillPath((New-Object System.Drawing.SolidBrush((C 255 255 255 70))), $gloss)
    $g.Restore($state)
}

# Four-leaf clover: every outline first, then every fill, so the leaves read as one shape.
function Draw-Clover($g, [float]$cx, [float]$cy, [float]$r) {
    $shapes = @()
    foreach ($deg in @(-90, 0, 90, 180)) {
        $a = [Math]::PI * $deg / 180
        $dx = [Math]::Cos($a); $dy = [Math]::Sin($a)
        $px = -$dy; $py = $dx
        $lx = $cx + $dx * $r * 0.58; $ly = $cy + $dy * $r * 0.58
        $lobe = $r * 0.3
        foreach ($side in @(-1, 1)) {
            $ox = $lx + $px * $r * 0.2 * $side; $oy = $ly + $py * $r * 0.2 * $side
            $e = New-Object System.Drawing.Drawing2D.GraphicsPath
            $e.AddEllipse(($ox - $lobe), ($oy - $lobe), ($lobe * 2), ($lobe * 2))
            $shapes += ,$e
        }
        $tri = New-Object System.Drawing.Drawing2D.GraphicsPath
        $tri.AddPolygon([System.Drawing.PointF[]]@(
            (P ($lx - $dx * $r * 0.02 + $px * $r * 0.47) ($ly - $dy * $r * 0.02 + $py * $r * 0.47)),
            (P ($lx - $dx * $r * 0.02 - $px * $r * 0.47) ($ly - $dy * $r * 0.02 - $py * $r * 0.47)),
            (P ($cx + $dx * $r * 0.06) ($cy + $dy * $r * 0.06))))
        $shapes += ,$tri
    }
    $stemInk = New-Object System.Drawing.Pen($ink, 26); $stemInk.StartCap = [System.Drawing.Drawing2D.LineCap]::Round; $stemInk.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $stemGreen = New-Object System.Drawing.Pen((C 60 170 70), 12); $stemGreen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round; $stemGreen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawBezier($stemInk, (P $cx $cy), (P ($cx + $r * 0.3) ($cy + $r * 0.5)), (P ($cx + $r * 0.55) ($cy + $r * 0.75)), (P ($cx + $r * 0.9) ($cy + $r * 0.95)))
    $outline = New-Object System.Drawing.Pen($ink, 14); $outline.LineJoin = $round
    foreach ($shape in $shapes) { $g.DrawPath($outline, $shape) }
    $g.DrawBezier($stemGreen, (P $cx $cy), (P ($cx + $r * 0.3) ($cy + $r * 0.5)), (P ($cx + $r * 0.55) ($cy + $r * 0.75)), (P ($cx + $r * 0.9) ($cy + $r * 0.95)))
    $leafRect = New-Object System.Drawing.RectangleF(($cx - $r), ($cy - $r), ($r * 2), ($r * 2))
    $leafBrush = Gradient-Brush $leafRect (C 150 245 120) (C 40 170 70)
    foreach ($shape in $shapes) { $g.FillPath($leafBrush, $shape) }
    $g.FillEllipse($leafBrush, ($cx - $r * 0.24), ($cy - $r * 0.24), ($r * 0.48), ($r * 0.48))
    # Leaf veins and a shine.
    $vein = New-Object System.Drawing.Pen((C 30 120 50 200), 5)
    foreach ($deg in @(-90, 0, 90, 180)) {
        $a = [Math]::PI * $deg / 180
        $g.DrawLine($vein, (P ($cx + [Math]::Cos($a) * $r * 0.3) ($cy + [Math]::Sin($a) * $r * 0.3)),
            (P ($cx + [Math]::Cos($a) * $r * 0.62) ($cy + [Math]::Sin($a) * $r * 0.62)))
    }
    $g.FillEllipse((New-Object System.Drawing.SolidBrush((C 255 255 255 110))), ($cx - $r * 0.38), ($cy - $r * 0.86), ($r * 0.2), ($r * 0.13))
}

# 7) LUCKY PACKS (Hype Crew) --------------------------------------------------------------------------
$icon = New-Icon; $bmp = $icon[0]; $g = $icon[1]
Fill-Background $g (C 170 90 255) (C 30 10 66)
Draw-Rays $g (C 255 230 150 32) 16 256 190
# Epic (purple) and Legendary (gold) cards fanned behind a four-leaf clover.
Draw-Card $g 214 180 128 176 -14 (C 200 120 255) (C 120 60 200) (C 60 20 120) (C 240 200 255) (C 190 110 255) $false
Draw-Card $g 306 172 128 176 12 (C 255 214 70) (C 255 190 60) (C 200 110 20) (C 255 250 200) (C 255 200 40) $false
Draw-Clover $g 176 238 86
Draw-Text $g 'LUCKY' 100 256 340 $gold $goldDeep $ink 20
Draw-Text $g 'PACKS' 78 256 426 (C 255 255 255) (C 230 205 255) $ink 16
Draw-Sparkle $g 400 92 22 (C 255 255 220 235)
Draw-Sparkle $g 112 116 16 (C 255 255 230 215)
Draw-Sparkle $g 414 262 13 (C 255 240 200 210)
Draw-Rim $g $goldDeep
$bmp.Save("$out\lucky-packs.png", [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# 8) TRIPLE OPEN (Hype Crew) --------------------------------------------------------------------------
$icon = New-Icon; $bmp = $icon[0]; $g = $icon[1]
Fill-Background $g (C 70 170 255) (C 10 24 74)
Draw-Rays $g (C 255 255 255 26) 16 256 190
# Three cards fanned out: Rare (blue), Epic (purple), Legendary (gold) in front.
Draw-Card $g 166 196 118 162 -20 (C 90 180 255) (C 60 130 230) (C 20 50 130) (C 210 240 255) (C 90 180 255) $false
Draw-Card $g 346 196 118 162 20 (C 200 120 255) (C 120 60 200) (C 60 20 120) (C 240 200 255) (C 190 110 255) $false
Draw-Card $g 256 176 126 172 0 (C 255 214 70) (C 255 190 60) (C 200 110 20) (C 255 250 200) (C 255 200 40) $false
# "x3" burst badge.
$badge = New-Object System.Drawing.RectangleF(336, 74, 92, 92)
$g.FillEllipse((New-Object System.Drawing.SolidBrush((C 0 0 0 90))), 340, 82, 92, 92)
$g.FillEllipse((Gradient-Brush $badge (C 255 110 110) (C 210 30 60)), $badge)
$g.DrawEllipse((New-Object System.Drawing.Pen($ink, 9)), $badge)
Draw-Text $g 'x3' 60 382 118 (C 255 255 255) (C 255 225 200) $ink 11
Draw-Text $g 'TRIPLE' 88 256 342 $gold $goldDeep $ink 20
Draw-Text $g 'OPEN' 82 256 428 (C 255 255 255) (C 200 230 255) $ink 16
Draw-Sparkle $g 96 132 18 (C 255 255 230 225)
Draw-Sparkle $g 440 262 13 (C 255 255 230 205)
Draw-Rim $g $goldDeep
$bmp.Save("$out\triple-open.png", [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# 9) +1 CREW SLOT (Hype Crew) -------------------------------------------------------------------------
$icon = New-Icon; $bmp = $icon[0]; $g = $icon[1]
Fill-Background $g (C 255 110 205) (C 64 10 54)
Draw-Rays $g (C 255 240 200 30) 16 256 190
# A crew card with a member silhouette, and a green "+" badge.
Draw-Card $g 232 178 140 190 -8 (C 255 130 220) (C 70 60 140) (C 24 20 64) (C 255 240 250) (C 255 150 225) $true
$plus = New-Object System.Drawing.RectangleF(300, 176, 124, 124)
$g.FillEllipse((New-Object System.Drawing.SolidBrush((C 0 0 0 95))), 305, 186, 124, 124)
$g.FillEllipse((Gradient-Brush $plus (C 130 245 120) (C 30 170 70)), $plus)
$g.DrawEllipse((New-Object System.Drawing.Pen($ink, 10)), $plus)
$bar = New-Object System.Drawing.SolidBrush((C 255 255 255))
$barPen = New-Object System.Drawing.Pen($ink, 8); $barPen.LineJoin = $round
$cross = [System.Drawing.PointF[]]@((P 350 204), (P 374 204), (P 374 226), (P 396 226), (P 396 250), (P 374 250), (P 374 272),
    (P 350 272), (P 350 250), (P 328 250), (P 328 226), (P 350 226))
$g.DrawPolygon($barPen, $cross)
$g.FillPolygon($bar, $cross)
Draw-Text $g '+1 CREW' 84 256 342 $gold $goldDeep $ink 18
Draw-Text $g 'SLOT' 82 256 428 (C 255 255 255) (C 255 215 240) $ink 16
Draw-Sparkle $g 110 128 20 (C 255 255 230 230)
Draw-Sparkle $g 404 98 16 (C 255 240 255 220)
Draw-Rim $g $goldDeep
$bmp.Save("$out\crew-slot.png", [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# 10) DUNK PASS: SEASON 1 ------------------------------------------------------------------
$icon = New-Icon; $bmp = $icon[0]; $g = $icon[1]
Fill-Background $g (C 255 150 40) (C 70 20 10)
Draw-Rays $g (C 255 240 190 34) 16 256 190
# A golden ticket with a basketball, tilted.
$state = $g.Save()
$g.TranslateTransform(256, 176)
$g.RotateTransform(-10)
$ticket = New-Object System.Drawing.Drawing2D.GraphicsPath
$ticket.AddArc(-150, -86, 40, 40, 180, 90); $ticket.AddArc(110, -86, 40, 40, 270, 90)
$ticket.AddArc(110, 46, 40, 40, 0, 90); $ticket.AddArc(-150, 46, 40, 40, 90, 90); $ticket.CloseFigure()
$ticketShadow = $ticket.Clone(); $m = New-Object System.Drawing.Drawing2D.Matrix; $m.Translate(6, 10); $ticketShadow.Transform($m)
$g.FillPath((New-Object System.Drawing.SolidBrush((C 0 0 0 100))), $ticketShadow)
$g.FillPath((Gradient-Brush (New-Object System.Drawing.RectangleF(-150, -86, 300, 172)) (C 255 238 130) (C 235 150 20)), $ticket)
$ticketPen = New-Object System.Drawing.Pen($ink, 12); $ticketPen.LineJoin = $round
$g.DrawPath($ticketPen, $ticket)
# Perforated stub line.
$dash = New-Object System.Drawing.Pen((C 150 80 10), 6); $dash.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$g.DrawLine($dash, 62, -72, 62, 72)
# Notches on the stub line.
$g.FillEllipse((New-Object System.Drawing.SolidBrush((C 70 20 10))), 48, -100, 28, 28)
$g.FillEllipse((New-Object System.Drawing.SolidBrush((C 70 20 10))), 48, 72, 28, 28)
Draw-Basketball $g -44 0 56
Draw-Sparkle $g 104 -2 16 (C 255 255 240 240)
$g.Restore($state)
Draw-Text $g 'DUNK' 112 256 334 $gold $goldDeep $ink 20
Draw-Text $g 'PASS' 86 256 422 (C 255 255 255) (C 255 225 190) $ink 16
Draw-Sparkle $g 96 110 20 (C 255 255 230 230)
Draw-Sparkle $g 420 96 16 (C 255 255 230 220)
Draw-Rim $g $goldDeep
$bmp.Save("$out\dunk-pass-s1.png", [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

Get-ChildItem $out | Select-Object Name, Length
