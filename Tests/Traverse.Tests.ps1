#Integration test example
Describe "Traverse PS$PSVersion Basic Command Testing" {
    Context 'Strict mode' { 
        Set-StrictMode -Version latest

        It 'Get-TraverseDevice errors if not connected' {
            {Get-TraverseDevice} | Should Throw 
        }
    }
}
