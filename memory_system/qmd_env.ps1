$QmdRoot = "C:\Users\Damian\life\Archives\qmd"
$env:XDG_CACHE_HOME = Join-Path $QmdRoot "cache"
$env:XDG_CONFIG_HOME = Join-Path $QmdRoot "config"

New-Item -ItemType Directory -Force -Path $QmdRoot | Out-Null
New-Item -ItemType Directory -Force -Path $env:XDG_CACHE_HOME | Out-Null
New-Item -ItemType Directory -Force -Path $env:XDG_CONFIG_HOME | Out-Null

$QmdCli = "C:\Users\Damian\AppData\Roaming\npm\node_modules\@tobilu\qmd\dist\cli\qmd.js"

function Invoke-Qmd {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    node $QmdCli @Arguments
}
