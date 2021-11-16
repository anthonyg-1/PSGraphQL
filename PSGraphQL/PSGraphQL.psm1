using namespace System
using namespace System.Collections.Generic

<#
.SYNOPSIS
    This PowerShell module contains functions that facilitate querying and create, update, and delete (mutations) operations for GraphQL endpoints.
.LINK
    https://graphql.org/
#>


#reegion Load Dependencies

Import-Module Microsoft.PowerShell.Utility -Function Invoke-RestMethod, Invoke-WebRequest, ConvertFrom-Json, ConvertTo-Json -Force -ErrorAction Stop

#endregion


#region Load Public Functions

Get-ChildItem -Path $PSScriptRoot\Functions\*.ps1 | Foreach-Object { . $_.FullName }

#endregion



#region Load Private Functions

Get-ChildItem -Path $PSScriptRoot\PrivateFunctions\*.ps1 | Foreach-Object { . $_.FullName }

#endregion
