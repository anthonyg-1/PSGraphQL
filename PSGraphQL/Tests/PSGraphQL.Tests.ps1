#requires -Module Pester
#requires -Module PSScriptAnalyzer

$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Set-Location -Path $here
Set-Location -Path ..

$module = 'PSGraphQL'

$moduleDirectory = Get-Item -Path ../$module | Select-Object -ExpandProperty FullName

Clear-Host

Describe "$module Module Structure and Validation Tests" -Tag Unit -WarningAction SilentlyContinue {
    Context "$module" {
        It "has the root module $module.psm1" {
            "$moduleDirectory/$module.psm1" | Should -Exist
        }

        It "has the a manifest file of $module.psd1" {
            "$moduleDirectory/$module.psd1" | Should -Exist
        }

        It "has Functions subdirectory" {
            "$moduleDirectory/Functions/*.ps1" | Should -Exist
        }

        It "$module is valid PowerShell code" {
            $psFile = Get-Content -Path "$moduleDirectory\$module.psm1" -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
            $errors.Count | Should -Be 0
        }
    }

    Context "Code Validation" {
        Get-ChildItem -Path "$moduleDirectory" -Filter *.ps1 -Recurse | ForEach-Object {
            It "$_ is valid PowerShell code" {
                $psFile = Get-Content -Path $_.FullName -ErrorAction Stop
                $errors = $null
                $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
                $errors.Count | Should -Be 0
            }
        }
    }

    Context "$module.psd1" {
        It "should not throw an exception in import" {
            $modPath = "$moduleDirectory/$module.psd1"
            { Import-Module -Name $modPath -Force -ErrorAction Stop } | Should Not Throw
        }
    }

}

Describe "Testing module and cmdlets against PSSA rules" -Tag Unit -WarningAction SilentlyContinue {
    $scriptAnalyzerRules = Get-ScriptAnalyzerRule

    Context "$module test against PSSA rules" {
        $modulePath = "$moduleDirectory\$module.psm1"

        $analysis = Invoke-ScriptAnalyzer -Path $modulePath

        foreach ($rule in $scriptAnalyzerRules) {
            It "should pass $rule" {
                If ($analysis.RuleName -contains $rule) {
                    $analysis | Where RuleName -eq $rule -OutVariable failures
                    $failures.Count | Should -Be 0
                }
            }
        }
    }

    Get-ChildItem -Path "$moduleDirectory\Functions" -Filter *.ps1 -Recurse | ForEach-Object {
        Context "$_ test against PSSA rules" {
            $analysis = Invoke-ScriptAnalyzer -Path $_.FullName -ExcludeRule PSUseShouldProcessForStateChangingFunctions

            foreach ($rule in $scriptAnalyzerRules) {
                It "should pass $rule" {
                    If ($analysis.RuleName -contains $rule) {
                        $analysis | Where RuleName -eq $rule -OutVariable failures
                        $failures.Count | Should -Be 0
                    }
                }
            }
        }
    }
}
