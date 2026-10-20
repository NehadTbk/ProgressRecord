Describe 'ProgressRecord module' {
    It 'imports without errors' {
        { Import-Module "$PSScriptRoot\..\src\ProgressRecord\ProgressRecord.psd1" -Force } | Should -Not -Throw
    }
}