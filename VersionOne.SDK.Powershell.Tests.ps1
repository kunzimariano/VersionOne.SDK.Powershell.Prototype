$moduleName = 'VersionOne.SDK.Powershell'
$module = Get-Module $moduleName
if($module -ne $null) { Remove-Module $moduleName }
Import-Module .\$moduleName.psm1 -args "https://www14.v1host.com/v1sdktesting", "admin", "admin"

function getMetaSample {
@'
<?xml version="1.0" encoding="UTF-8"?>
<Meta href="/v1sdktesting/meta.v1/" version="14.1.5.78">
    
    <AssetType name="Story" token="Story" abstract="False">
        <Name href="/v1sdktesting/meta.v1/Story/Name" tokenref="Story.Name"/>
        <AttributeDefinition name="ChangeDate" token="Story.ChangeDate" displayname="AttributeDefinition'ChangeDate'Story" attributetype="Date" isreadonly="True" isrequired="False" ismultivalue="False" iscanned="True" iscustom="False"><Base href="/v1sdktesting/meta.v1/BaseAsset/ChangeDate" tokenref="BaseAsset.ChangeDate"/><OrderByAttribute href="/v1sdktesting/meta.v1/Story/ChangeDate" tokenref="Story.ChangeDate"/></AttributeDefinition>
        <AttributeDefinition name="RetireDate" token="Story.RetireDate" displayname="AttributeDefinition'RetireDate'Story" attributetype="Date" isreadonly="True" isrequired="False" ismultivalue="False" iscanned="True" iscustom="False"><Base href="/v1sdktesting/meta.v1/BaseAsset/RetireDate" tokenref="BaseAsset.RetireDate"/><OrderByAttribute href="/v1sdktesting/meta.v1/Story/RetireDate" tokenref="Story.RetireDate"/></AttributeDefinition>
    </AssetType>

    <AssetType name="Member" token="Member" displayname="AssetType'Member" abstract="False">
        <Name href="/v1sdktesting/meta.v1/Member/Name" tokenref="Member.Name"/>
        
        <AttributeDefinition name="ChangeDate" token="Member.ChangeDate" displayname="AttributeDefinition'ChangeDate'Member" attributetype="Date" isreadonly="True" isrequired="False" ismultivalue="False" iscanned="True" iscustom="False">
            <Base href="/v1sdktesting/meta.v1/BaseAsset/ChangeDate" tokenref="BaseAsset.ChangeDate"/>
            <OrderByAttribute href="/v1sdktesting/meta.v1/Member/ChangeDate" tokenref="Member.ChangeDate"/>
        </AttributeDefinition>
        
        <AttributeDefinition name="RetireDate" token="Member.RetireDate" displayname="AttributeDefinition'RetireDate'Member" attributetype="Date" isreadonly="True" isrequired="False" ismultivalue="False" iscanned="True" iscustom="False">
            <Base href="/v1sdktesting/meta.v1/BaseAsset/RetireDate" tokenref="BaseAsset.RetireDate"/>
            <OrderByAttribute href="/v1sdktesting/meta.v1/Member/RetireDate" tokenref="Member.RetireDate"/>
        </AttributeDefinition>
    </AssetType>
</Meta>
'@
}

function getNewQueryObject {
    [pscustomobject] @{ 
		Token = $null;
		ID = $null;
		SelectExpression = $null;
		WhereExpression = $null;
        Executed = $false;		
	}
}

Describe "Get-V1Metamodel" {
    Context "when calling it" {
        Mock -moduleName $moduleName -commandName Get-MetaObject -mockWith { [xml](getMetaSample)} -verifiable
        $meta = Get-V1Metamodel
        
        It "calls Get-MetaObject" {
            Assert-VerifiableMocks
        }
        
        It "returns the metaobject based on the xml file" {
            $meta.Story.Token | should be 'Story'
            $meta.Member.Token | should be 'Member'
            $meta.Foo | should be $null
            $meta.Story.ChangeDate | Should not be $null
            $meta.Story.RetireDate | Should not be $null
            $meta.Story.Foo | Should be $null
            $meta.Member.ChangeDate | Should not be $null
            $meta.Member.RetireDate | Should not be $null            
        }
    }
}

Describe "Start-V1Query" {
    Context "when calling it with an asset object and id" {
        $asset = [pscustomobject]@{ Token = 'SomeAsset'}
        $q = ($asset | Start-V1Query 1234)
        It "returns a query object with populated values" {	
            $q | Should not be $null            
            $q.Id | Should be 1234
            $q.Token | Should be 'SomeAsset'
            $q.SelectExpression | Should be $null
            $q.WhereExpression | Should be $null
            $q.Executed | Should be $false
        }
    }
}

Describe "Invoke-V1Select" {
    Context "when calling it with a new queryObject" {        
        $q = getNewQueryObject | Invoke-V1Select 'name','email','date'
        
        It "returns the same query object but properly modified" {
            $q | Should not be $null            
            $q.Id | Should be $null
            $q.Token | Should be $null
            $q.SelectExpression | Should be 'name,email,date'
            $q.WhereExpression | Should be $null
            $q.Executed | Should be $false        
        }
    }
}

Describe "Invoke-V1Where" {
    Context "when calling it with a new queryObject" {        
        $q = getNewQueryObject | Invoke-V1Where { $s.Name -eq 'My New Story' } 
        
        It "returns the same query object but properly modified" {
            $q | Should not be $null            
            $q.Id | Should be $null
            $q.Token | Should be $null
            $q.SelectExpression | Should be $null
            $q.WhereExpression | Should be "Name='My New Story'"
            $q.Executed | Should be $false     
        }
        
        $q = getNewQueryObject | Invoke-V1Where { $s.Name.More -eq 'Some Value' -and $s.Status.Name -ne 'Done'  } 
        
        It "returns the same query object but properly modified" {
            $q | Should not be $null            
            $q.Id | Should be $null
            $q.Token | Should be $null
            $q.SelectExpression | Should be $null
            $q.WhereExpression | Should be "Name.More='Some Value';Status.Name!='Done'"
            $q.Executed | Should be $false     
        }
    }
}