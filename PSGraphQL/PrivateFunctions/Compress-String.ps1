# Compresses and trims GraphQL operations for processing by this module's functions:
function Compress-String([string]$InputString) {
    $output = ($InputString -replace "`r`n|`n", " ").Trim()
    return $output
}
