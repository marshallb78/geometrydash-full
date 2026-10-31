$ErrorActionPreference = "Stop"
$resDir = "C:\Program Files (x86)\Steam\steamapps\common\Geometry Dash\Resources"
$exePath = "C:\Program Files (x86)\Steam\steamapps\common\Geometry Dash\GeometryDash.exe"
$rootDir = "w:\G+3\Geometry Dash\GD-2.205-Decompiled-main"

New-Item -ItemType Directory -Force -Path "$rootDir\assets\textures" | Out-Null
New-Item -ItemType Directory -Force -Path "$rootDir\assets\data" | Out-Null
New-Item -ItemType Directory -Force -Path "$rootDir\assets\levels" | Out-Null
New-Item -ItemType Directory -Force -Path "$rootDir\assets\audio" | Out-Null

Write-Host "1. Copying HD Sprite Sheets, Backgrounds, and Grounds..."
$sheets = @(
    "GJ_GameSheet-hd", "GJ_GameSheet02-hd", "GJ_GameSheet03-hd", "GJ_GameSheet04-hd",
    "GJ_GameSheetGlow-hd", "GJ_GameSheetIcons-hd", "GJ_GameSheetEditor-hd",
    "PixelSheet_01-hd", "FireSheet_01-hd", "GJ_LaunchSheet-hd", "GJ_ParticleSheet-hd",
    "GauntletSheet-hd", "TowerSheet-hd", "DungeonSheet-hd", "SecretSheet-hd",
    "TreasureRoomSheet-hd", "WorldSheet-hd"
)
foreach ($sh in $sheets) {
    if (Test-Path "$resDir\$sh.png") {
        Copy-Item "$resDir\$sh.png" "$rootDir\assets\textures\$sh.png" -Force
    }
}
Copy-Item "$resDir\GJ_gradientBG-hd.png" "$rootDir\assets\textures\GJ_gradientBG-hd.png" -Force
Get-ChildItem "$resDir\game_bg_*_001-hd.png" | ForEach-Object {
    Copy-Item $_.FullName "$rootDir\assets\textures\$($_.Name)" -Force
}
Get-ChildItem "$resDir\groundSquare_*_001-hd.png" | ForEach-Object {
    Copy-Item $_.FullName "$rootDir\assets\textures\$($_.Name)" -Force
}

Write-Host "2. Parsing Cocos2d -hd.plist Atlases into assets/data/sprites.json..."
$framesMap = [ordered]@{}
for ($sIdx = 0; $sIdx -lt $sheets.Count; $sIdx++) {
    $sh = $sheets[$sIdx]
    $plistPath = "$resDir\$sh.plist"
    if (-not (Test-Path $plistPath)) { continue }
    [xml]$xml = Get-Content $plistPath -Raw
    $mainDict = $xml.plist.dict
    $framesDict = $null
    for ($i = 0; $i -lt $mainDict.ChildNodes.Count; $i++) {
        if ($mainDict.ChildNodes[$i].Name -eq 'key' -and $mainDict.ChildNodes[$i].InnerText -eq 'frames') {
            $framesDict = $mainDict.ChildNodes[$i + 1]
            break
        }
    }
    if (-not $framesDict) { continue }
    for ($i = 0; $i -lt $framesDict.ChildNodes.Count; $i += 2) {
        $fName = $framesDict.ChildNodes[$i].InnerText
        $fNode = $framesDict.ChildNodes[$i + 1]
        if ($framesMap.Contains($fName)) { continue }
        $offset = "{0,0}"
        $sourceSize = "{0,0}"
        $rect = "{{0,0},{0,0}}"
        $rotated = 0
        for ($j = 0; $j -lt $fNode.ChildNodes.Count; $j += 2) {
            $k = $fNode.ChildNodes[$j].InnerText
            $vNode = $fNode.ChildNodes[$j + 1]
            switch ($k) {
                "spriteOffset" { $offset = $vNode.InnerText }
                "spriteSourceSize" { $sourceSize = $vNode.InnerText }
                "textureRect" { $rect = $vNode.InnerText }
                "textureRotated" { $rotated = if ($vNode.Name -eq "true") { 1 } else { 0 } }
            }
        }
        $rNums = [regex]::Matches($rect, '-?\d+(?:\.\d+)?') | ForEach-Object { [double]$_.Value }
        $oNums = [regex]::Matches($offset, '-?\d+(?:\.\d+)?') | ForEach-Object { [double]$_.Value }
        $sNums = [regex]::Matches($sourceSize, '-?\d+(?:\.\d+)?') | ForEach-Object { [double]$_.Value }
        $framesMap[$fName] = @(
            $sIdx,
            $rNums[0], $rNums[1], $rNums[2], $rNums[3],
            $oNums[0], $oNums[1],
            $sNums[0], $sNums[1],
            $rotated
        )
    }
}
$spritesOut = [ordered]@{
    scaleFactor = 2
    sheets = $sheets
    frames = $framesMap
}
$spritesJson = $spritesOut | ConvertTo-Json -Depth 4 -Compress
[System.IO.File]::WriteAllText("$rootDir\assets\data\sprites.json", $spritesJson)
Write-Host ("   Saved sprites.json ({0:N1} KB, {1} frames)" -f ($spritesJson.Length / 1KB), $framesMap.Count)

Write-Host "3. Building assets/data/objects.json..."
$extractedFrames = @{}
$tbLines = Get-Content "$rootDir\GD\code\src\ObjectToolbox.cpp"
foreach ($line in $tbLines) {
    if ($line -match 'ADD_TO_TOOLBOX\((\d+),\s*"([^"]+)"\)') {
        $extractedFrames[$Matches[1]] = $Matches[2]
    }
}
$extractedFrames["44"] = "checkpoint_01_001.png"

$exeBytes = [System.IO.File]::ReadAllBytes($exePath)
for ($p = 0x330000; $p -lt 0x385000; $p++) {
    if ($exeBytes[$p] -eq 0x48 -and $exeBytes[$p+1] -eq 0x8B -and $exeBytes[$p+2] -eq 0xC8 -and
        $exeBytes[$p+3] -eq 0x48 -and $exeBytes[$p+4] -eq 0x8D -and $exeBytes[$p+5] -eq 0x15 -and $exeBytes[$p+10] -eq 0xE8) {
        $objId = -1
        for ($k = 10; $k -le 32; $k++) {
            if ($exeBytes[$p-$k] -eq 0xC7 -and ($exeBytes[$p-$k+1] -eq 0x85 -or $exeBytes[$p-$k+1] -eq 0x45)) {
                $offsetLen = if ($exeBytes[$p-$k+1] -eq 0x85) { 6 } else { 3 }
                $objId = [BitConverter]::ToInt32($exeBytes, $p - $k + $offsetLen)
                break
            }
        }
        if ($objId -gt 0 -and $objId -lt 10000) {
            $disp = [BitConverter]::ToInt32($exeBytes, $p + 6)
            $leaNextRva = 4096 + ($p + 10 - 1024)
            $strRva = $leaNextRva + $disp
            $strFileOff = 5322240 + ($strRva - 5328896)
            if ($strFileOff -ge 0 -and $strFileOff -lt $exeBytes.Length - 100) {
                $len = 0
                while ($exeBytes[$strFileOff + $len] -ne 0 -and $len -lt 100) { $len++ }
                $str = [System.Text.Encoding]::ASCII.GetString($exeBytes, $strFileOff, $len)
                if ($str -match '\.png$') { $extractedFrames["$objId"] = $str }
            }
        }
    }
}

$longDataRaw = Get-Content "$env:TEMP\OpenGD_LongData.cpp" -Raw
$hitboxes = @{}
$hbSection = $longDataRaw.Substring(0, $longDataRaw.IndexOf("_pHitboxRadius"))
[regex]::Matches($hbSection, '\{(\d+),\s*\{(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)\}\}') | ForEach-Object {
    $id = $_.Groups[1].Value
    $h = [double]$_.Groups[2].Value
    $w = [double]$_.Groups[3].Value
    $x = [double]$_.Groups[4].Value
    $y = [double]$_.Groups[5].Value
    $hitboxes[$id] = @($w, $h, $x, $y)
}

$radii = @{}
$radSection = $longDataRaw.Substring($longDataRaw.IndexOf("_pHitboxRadius"), $longDataRaw.IndexOf("_pBlocks") - $longDataRaw.IndexOf("_pHitboxRadius"))
[regex]::Matches($radSection, '\{(\d+),\s*(-?\d+(?:\.\d+)?)\}') | ForEach-Object {
    $radii[$_.Groups[1].Value] = [double]$_.Groups[2].Value
}

$solidsSet = @{}
$solSection = $longDataRaw.Substring($longDataRaw.IndexOf("_pSolids"), $longDataRaw.IndexOf("_pTriggers") - $longDataRaw.IndexOf("_pSolids"))
[regex]::Matches($solSection, '\b(\d+)\b') | ForEach-Object { $solidsSet[$_.Groups[1].Value] = 1 }

$triggersSet = @{}
$trigSection = $longDataRaw.Substring($longDataRaw.IndexOf("_pTriggers"))
[regex]::Matches($trigSection, '\b(\d+)\b') | ForEach-Object { $triggersSet[$_.Groups[1].Value] = 1 }

function Convert-Children($children) {
    if (-not $children -or $children.Count -eq 0) { return $null }
    $arr = @()
    foreach ($ch in $children) {
        if ($ch.texture_name) {
            $item = [ordered]@{
                f = $ch.texture_name
                x = if ($null -ne $ch.x) { [double]$ch.x } else { 0 }
                y = if ($null -ne $ch.y) { [double]$ch.y } else { 0 }
                r = if ($null -ne $ch.rot) { [double]$ch.rot } else { 0 }
                sx = if ($null -ne $ch.scale_x) { [double]$ch.scale_x } else { 1 }
                sy = if ($null -ne $ch.scale_y) { [double]$ch.scale_y } else { 1 }
                ax = if ($null -ne $ch.anchor_x) { [double]$ch.anchor_x } else { 0.5 }
                ay = if ($null -ne $ch.anchor_y) { [double]$ch.anchor_y } else { 0.5 }
                fx = if ($ch.flip_x) { 1 } else { 0 }
                fy = if ($ch.flip_y) { 1 } else { 0 }
                z = if ($null -ne $ch.z) { [int]$ch.z } else { -1 }
                cc = if ($ch.color_channel) { $ch.color_channel } else { "" }
            }
            $sub = Convert-Children $ch.children
            if ($sub) { $item.ch = $sub }
            $arr += $item
        }
    }
    return $arr
}

$openGdObj = Get-Content "$env:TEMP\OpenGD_object.json" -Raw | ConvertFrom-Json
$objectsOut = [ordered]@{}

$allIds = ($extractedFrames.Keys + $openGdObj.PSObject.Properties.Name) | Sort-Object -Unique { [int]$_ }
foreach ($idStr in $allIds) {
    $idInt = [int]$idStr
    $og = $openGdObj.PSObject.Properties[$idStr].Value
    $frame = if ($extractedFrames.ContainsKey($idStr)) { $extractedFrames[$idStr] } elseif ($og -and $og.texture_name) { $og.texture_name } else { "" }
    $objType = if ($og -and $null -ne $og.object_type) { [int]$og.object_type } else { 7 }
    $zL = if ($og -and $null -ne $og.default_z_layer) { [int]$og.default_z_layer } else { 1 }
    $zO = if ($og -and $null -ne $og.default_z_order) { [int]$og.default_z_order } else { 2 }
    $c1 = if ($og -and $null -ne $og.default_primary_channel) { [int]$og.default_primary_channel } else { -1 }
    $c2 = if ($og -and $null -ne $og.default_secondary_channel) { [int]$og.default_secondary_channel } else { -1 }
    $cc = if ($og -and $og.color_channel) { $og.color_channel } elseif ($idInt -gt 1911 -and $frame -notmatch '^edit_e') { "base" } else { "" }

    $isTrigger = if ($triggersSet.ContainsKey($idStr) -or $frame -match '^edit_e') { 1 } else { 0 }
    $isSolid = if ($solidsSet.ContainsKey($idStr) -or $objType -eq 0) { 1 } else { 0 }
    $hb = if ($hitboxes.ContainsKey($idStr)) { $hitboxes[$idStr] } else { $null }

    switch ($idInt) {
        36   { $objType = 11 }
        84   { $objType = 13 }
        141  { $objType = 12 }
        142  { $objType = 22; $hb = @(38, 38, -19, -19) }
        747  { $objType = 28 }
        918  { $objType = 2 }
        919  { $objType = 2 }
        1022 { $objType = 29 }
        1275 { $objType = 32 }
        1327 { $objType = 2 }
        1328 { $objType = 2 }
        1329 { $objType = 31; $hb = @(38, 38, -19, -19) }
        1330 { $objType = 39 }
        1333 { $objType = 36 }
        1584 { $objType = 2 }
        1587 { $objType = 32 }
        1589 { $objType = 32 }
        1594 { $objType = 30 }
        1598 { $objType = 32 }
        1614 { $objType = 32 }
        1704 { $objType = 37 }
        1751 { $objType = 38 }
        1910 { $objType = 0; $isSolid = 1; $hb = @(15, 15, -7.5, -7.5) }
        1911 { $objType = 0; $isSolid = 1 }
        1933 { $objType = 47; $hb = @(44, 92, -22, -46) }
        2063 { $objType = 48; $hb = @(24, 40, -12, -20) }
        2902 { $objType = 49; $hb = @(34, 86, -17, -43) }
        3004 { $objType = 44; $hb = @(36, 36, -18, -18) }
        3005 { $objType = 45; $hb = @(25, 4, -12.5, -2) }
        3027 { $objType = 46; $hb = @(36, 36, -18, -18) }
        3600 { $isTrigger = 1 }
    }
    if ($radii.ContainsKey($idStr) -and $objType -eq 7) { $objType = 2 }

    $entry = [ordered]@{
        f = $frame
        t = $objType
        zL = $zL
        zO = $zO
    }
    if ($c1 -ne -1) { $entry.c1 = $c1 }
    if ($c2 -ne -1) { $entry.c2 = $c2 }
    if ($cc -ne "") { $entry.cc = $cc }
    if ($hb) { $entry.hb = $hb }
    if ($radii.ContainsKey($idStr)) { $entry.r = $radii[$idStr] }
    if ($isSolid -eq 1) { $entry.s = 1 }
    if ($isTrigger -eq 1) { $entry.tr = 1 }
    if (($idInt -ge 515 -and $idInt -le 640) -or ($idInt -in @(366,367,1717,1718,1723,1724))) {
        $entry.inv = 1
    }
    if ($og -and $og.children) {
        $chArr = Convert-Children $og.children
        if ($chArr -and $chArr.Count -gt 0) { $entry.ch = $chArr }
    }
    $objectsOut[$idStr] = $entry
}

$objectsJson = $objectsOut | ConvertTo-Json -Depth 10 -Compress
[System.IO.File]::WriteAllText("$rootDir\assets\data\objects.json", $objectsJson)
Write-Host ("   Saved objects.json ({0:N1} KB, {1} objects)" -f ($objectsJson.Length / 1KB), $objectsOut.Count)

Write-Host "4. Copying and cleaning all 27 official level files..."
$levelsMeta = @(
    @{ id=1;    name="Stereo Madness";        song="StereoMadness.mp3";        artist="ForeverBound"; diff=1; stars=1;  coins=3 },
    @{ id=2;    name="Back On Track";         song="BackOnTrack.mp3";          artist="DJVI";         diff=1; stars=2;  coins=3 },
    @{ id=3;    name="Polargeist";            song="Polargeist.mp3";           artist="Step";         diff=2; stars=3;  coins=3 },
    @{ id=4;    name="Dry Out";               song="DryOut.mp3";               artist="DJVI";         diff=2; stars=4;  coins=3 },
    @{ id=5;    name="Base After Base";       song="BaseAfterBase.mp3";        artist="DJVI";         diff=3; stars=5;  coins=3 },
    @{ id=6;    name="Cant Let Go";           song="CantLetGo.mp3";            artist="DJVI";         diff=3; stars=6;  coins=3 },
    @{ id=7;    name="Jumper";                song="Jumper.mp3";               artist="Waterflame";   diff=4; stars=7;  coins=3 },
    @{ id=8;    name="Time Machine";          song="TimeMachine.mp3";          artist="Waterflame";   diff=4; stars=8;  coins=3 },
    @{ id=9;    name="Cycles";                song="Cycles.mp3";               artist="DJVI";         diff=4; stars=9;  coins=3 },
    @{ id=10;   name="xStep";                 song="xStep.mp3";                artist="DJVI";         diff=5; stars=10; coins=3 },
    @{ id=11;   name="Clutterfunk";           song="Clutterfunk.mp3";          artist="Waterflame";   diff=5; stars=11; coins=3 },
    @{ id=12;   name="Theory of Everything";  song="TheoryOfEverything.mp3";   artist="DJ-Nate";      diff=5; stars=12; coins=3 },
    @{ id=13;   name="Electroman Adventures"; song="Electroman.mp3";           artist="Waterflame";   diff=5; stars=10; coins=3 },
    @{ id=14;   name="Clubstep";              song="Clubstep.mp3";             artist="DJ-Nate";      diff=6; stars=14; coins=3; demon=$true; reqCoins=10 },
    @{ id=15;   name="Electrodynamix";        song="Electrodynamix.mp3";       artist="DJ-Nate";      diff=5; stars=12; coins=3 },
    @{ id=16;   name="Hexagon Force";         song="HexagonForce.mp3";         artist="Waterflame";   diff=5; stars=12; coins=3 },
    @{ id=17;   name="Blast Processing";      song="BlastProcessing.mp3";      artist="Waterflame";   diff=4; stars=10; coins=3 },
    @{ id=18;   name="Theory of Everything 2";song="TheoryOfEverything2.mp3";  artist="DJ-Nate";      diff=6; stars=14; coins=3; demon=$true; reqCoins=20 },
    @{ id=19;   name="Geometrical Dominator"; song="GeometricalDominator.mp3"; artist="Waterflame";   diff=4; stars=10; coins=3 },
    @{ id=20;   name="Deadlocked";            song="Deadlocked.mp3";           artist="F-777";        diff=6; stars=15; coins=3; demon=$true; reqCoins=30 },
    @{ id=21;   name="Fingerdash";            song="Fingerdash.mp3";           artist="MDK";          diff=5; stars=12; coins=3 },
    @{ id=22;   name="Dash";                  song="Dash.mp3";                 artist="MDK";          diff=5; stars=12; coins=3 },
    @{ id=3001; name="The Challenge";         song="DJRubRub.mp3";             artist="RobTop";       diff=2; stars=3;  coins=0 },
    @{ id=5001; name="The Tower";             song="tower01.mp3";              artist="RobTop";       diff=2; stars=5;  coins=3; platformer=$true },
    @{ id=5002; name="The Sewers";            song="tower01.mp3";              artist="RobTop";       diff=3; stars=5;  coins=3; platformer=$true },
    @{ id=5003; name="The Cellar";            song="tower01.mp3";              artist="RobTop";       diff=4; stars=5;  coins=3; platformer=$true },
    @{ id=5004; name="The Secret Hollow";     song="tower01.mp3";              artist="RobTop";       diff=5; stars=6;  coins=3; platformer=$true }
)

foreach ($lm in $levelsMeta) {
    $lid = $lm.id
    $raw = (Get-Content "$resDir\levels\$lid.txt" -Raw).Trim()
    if ($raw -match '^([A-Za-z0-9_\-]+={0,2})') {
        $cleanB64 = $Matches[1].Replace('-', '+').Replace('_', '/')
        switch ($cleanB64.Length % 4) { 2 { $cleanB64 += '==' } 3 { $cleanB64 += '=' } }
        [System.IO.File]::WriteAllText("$rootDir\assets\levels\$lid.txt", $cleanB64)
    }
}
$levelsMetaJson = $levelsMeta | ConvertTo-Json -Depth 4
[System.IO.File]::WriteAllText("$rootDir\assets\data\levels_meta.json", $levelsMetaJson)
Write-Host "   Saved 27 cleaned levels in assets/levels/ and assets/data/levels_meta.json"

Write-Host "5. Copying official audio files into assets/audio/..."
Get-ChildItem "$resDir\*.mp3", "$resDir\*.ogg" | ForEach-Object {
    Copy-Item $_.FullName "$rootDir\assets\audio\$($_.Name)" -Force
}
Write-Host "Asset build complete!"
