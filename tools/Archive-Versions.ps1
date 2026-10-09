param([string]$Group,[string]$VersionPath,[string]$PackagePath,[switch]$Sweep)
$ErrorActionPreference='Stop'
$root='D:\Codex'
$archive=Join-Path $root '旧版本与过期内容'
$index=Join-Path $root '版本索引.json'
$mutex=New-Object Threading.Mutex($false,'Local\CodexVersionRetention')
if(-not $mutex.WaitOne(10000)){throw 'Another version archive operation is active'}
try {
    $loaded=$false; $records=@()
    if(Test-Path -LiteralPath $index){$decoded=Get-Content -LiteralPath $index -Raw -Encoding UTF8 | ConvertFrom-Json; $records=@($decoded)}
    foreach($r in $records){if(-not $r.group -or -not $r.id -or -not $r.completed){throw "Invalid version index; existing index retained"}}
    $loaded=$true
    foreach($r in $records | Where-Object archived){
        $missing=@($r.archivePaths | Where-Object {-not(Test-Path -LiteralPath $_)})
        $r | Add-Member -NotePropertyName archiveUnavailable -NotePropertyValue ($missing.Count -gt 0) -Force
    }
    if($VersionPath){
        if(-not $Group -or $Group -match '[\\/:*?"<>|]' -or $Group -in @('.','..')){throw 'A valid artifact group is required'}
        $version=[IO.Path]::GetFullPath($VersionPath).TrimEnd('\')
        if(-not $version.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase) -or $version.StartsWith($archive+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Versions must be inside the active D:\Codex workspace'}
        if($version.StartsWith('D:\Codex\必要依赖\',[StringComparison]::OrdinalIgnoreCase)){throw 'Required dependencies cannot be archived'}
        $item=Get-Item -LiteralPath $version -Force
        if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Use a new version directory; this path is already archived'}
        $paths=@($version)
        if($PackagePath){$paths+=([IO.Path]::GetFullPath($PackagePath))}
        $records=@($records | Where-Object {$_.group -ne $Group -or $_.id -ne $item.Name})
        $records += [PSCustomObject]@{group=$Group;id=$item.Name;completed=(Get-Date).ToString('o');paths=$paths;archived=$false;archivePaths=@()}
    }
    foreach($set in ($records | Group-Object group)){
        $active=@($set.Group | Where-Object {-not $_.archived} | Sort-Object { [DateTime]$_.completed } -Descending)
        foreach($old in ($active | Select-Object -Skip 2)){
            if($old.group -in @('.','..') -or $old.group -match '[\\/:*?"<>|]' -or $old.id -match '[\\/:*?"<>|]' -or $old.id -in @('.','..')){throw 'Invalid archive identifier'}
            $folder=Join-Path (Join-Path $archive $old.group) $old.id
            $destinations=@()
            foreach($path in $old.paths){
                $src=[IO.Path]::GetFullPath($path).TrimEnd('\')
                $dst=[IO.Path]::GetFullPath((Join-Path $folder ([IO.Path]::GetFileName($src))))
                if(-not $src.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase) -or $src.StartsWith($archive+'\',[StringComparison]::OrdinalIgnoreCase) -or -not $dst.StartsWith($archive+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Archive path escaped its approved workspace'}
                if(Test-Path -LiteralPath $src){
                    $sourceItem=Get-Item -LiteralPath $src -Force
                    if($sourceItem.Attributes -band [IO.FileAttributes]::ReparsePoint){
                        if([IO.Path]::GetFullPath([string]$sourceItem.Target).TrimEnd('\') -ne $dst){throw 'Unexpected compatibility link'}
                    }else{
                        if(Test-Path -LiteralPath $dst){throw ('Destination already exists: '+$dst)}
                        New-Item -ItemType Directory -Path $folder -Force | Out-Null
                        Move-Item -LiteralPath $src -Destination $dst
                    }
                }elseif(-not (Test-Path -LiteralPath $dst)){throw ('Missing version payload: '+$src)}
                # Remove only an exact legacy C: alias; never link active paths back to disposable archives.
                if($old.group -eq '嘉豪训练器'){
                    $compatRoot='C:\AIgame\apps\jiahao-trainer\builds'
                    $compat=Join-Path $compatRoot $old.id
                    $alias=Get-Item -LiteralPath $compat -Force -ErrorAction SilentlyContinue
                    if($alias -and $alias.LinkType -eq 'Junction' -and [string]$alias.Target -eq $src){[IO.Directory]::Delete($compat)}
                }
                $destinations+=$dst
            }
            $old.archived=$true
            $old.archivePaths=$destinations
            Write-Output ('Archived '+$old.group+' / '+$old.id)
        }
    }
}finally{
    if($loaded){$tempIndex=$index+".tmp"; ConvertTo-Json -InputObject @($records) -Depth 7 | Set-Content -LiteralPath $tempIndex -Encoding UTF8; if(Test-Path -LiteralPath $index){[IO.File]::Replace($tempIndex,$index,$index+".bak")}else{Move-Item -LiteralPath $tempIndex -Destination $index}}
    $mutex.ReleaseMutex();$mutex.Dispose()
}
