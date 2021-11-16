# Compresses and trims GraphQL operations for processing by this module's functions:
function Compress-String([string]$InputString) {
    return ($InputString -replace '\s+', ' ').Trim()
}
