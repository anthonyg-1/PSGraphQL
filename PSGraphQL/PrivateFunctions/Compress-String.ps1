# Compresses and trims GraphQL operations for processing by this module's functions:
function Compress-String([string]$InputString) {
    $output = ([String]::Join(" ",($InputString.Split("`n")))).Trim()
    return $output
}
