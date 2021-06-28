
<#
.SYNOPSIS
    This PowerShell module contains functions that facilitate querying and create, update, and delete (mutations) operations for GraphQL endpoints.
.LINK
    https://graphql.org/
#>


#reegion Load Dependencies

Import-Module Microsoft.PowerShell.Utility -Function Invoke-RestMethod -Force

#endregion


#region Load Public Functions

Get-ChildItem -Path $PSScriptRoot\Functions\*.ps1 | Foreach-Object { . $_.FullName }

#endregion
