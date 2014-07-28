$moduleName = 'VersionOne.SDK.Powershell'
$module = Get-Module $moduleName
if($module -ne $null) { Remove-Module $moduleName }
Import-Module .\$moduleName.psm1 -args "https://www14.v1host.com/v1sdktesting", "admin", "admin"

Describe "Start-V1Query" {
    Context "when calling Start-V1Query with an asset object and id" {
        $asset = [pscustomobject]@{ Token = 'SomeAsset'}
        $q = ($asset | Start-V1Query 1234)
        It "should return a query object with populated values" {	
            $q | Should not be $null            
            $q.Id | Should be 1234
            $q.Token | Should be 'SomeAsset'
            $q.SelectExpression | Should be $null
            $q.WhereExpression | Should be $null
            $q.Executed | Should be $false
        }
    }
}