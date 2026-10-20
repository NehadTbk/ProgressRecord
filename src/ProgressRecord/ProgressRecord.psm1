$private = @(Get-ChildItem -Path "$PSScriptRoot\Private" -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue)
$public = @(Get-ChildItem -Path "$PSScriptRoot\Public" -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue)

foreach ($file in $private + $public) {
    try {
        . $file.FullName
    }
    catch {
        throw "Could not load $($file.FullName): $_"
    }
}

if ($public.Count -gt 0) {
    Export-ModuleMember -Function $public.BaseName
}
