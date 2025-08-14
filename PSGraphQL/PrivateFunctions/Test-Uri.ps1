function Test-Uri {
    param (
        [Parameter(Mandatory)]
        [String]$InputString
    )

    try {
        [void][System.Uri]::new($InputString)
        return $true
    }
    catch {
        return $false
    }
}
