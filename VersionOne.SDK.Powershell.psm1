# TODO: this help format does not work for modules, but the .EXAMPLES are valid examples for using this module's code.
<# 
.SYNOPSIS 
	A simple Powershell module for querying VersionOne.
.DESCRIPTION 
	More details here
.NOTES 
 	Notes to go here. 
.LINK 
    http://www.github.com/versionone/VersionOne.SDK.Powershell.Prototype
.EXAMPLE 
	# Short-form with aliases:
	Import-Module .\VersionOne.SDK.Powershell.psm1 -args "https://www14.v1host.com/v1sdktesting", "admin", "admin"	
	$s = (vmeta).Story; $s | vquery 37741 | vselect $s.Name, $s.ID, $s.CreateDate | vfetch
.EXAMPLE 
	# Long-form:
	Import-Module .\VersionOne.SDK.Powershell.psm1 -args "https://www14.v1host.com/v1sdktesting", "admin", "admin"
	$s = (Get-V1Metamodel).Story; $s | Start-V1Query 37741 | Invoke-V1Select $s.Name, $s.ID, $s.CreateDate | Invoke-V1Fetch
#>
param(
  	[parameter(Position=0,Mandatory=$true)][string]$baseUrl,
    [parameter(Position=1,Mandatory=$true)][string]$user,
	[parameter(Position=2,Mandatory=$true)][string]$password
)

#TODO: The whole thing should be a module and we should only make public functions that require it
#TODO: Endpoints should be configurable

#$metaFile = [IO.Path]::GetTempFileName()

$metaFile="meta.xml"

function Get-RestUrl {
    "$baseUrl/rest-1.v1/Data/"
}

function Get-MetaUrl {
    "$baseUrl/meta.v1/"
}

function Get-MultipleAssets {
	param($xmlObject)
	# TODO: review if using an array or something else
	$result = @()
	$xmlObject.Assets.Asset | % {
		$asset = [pscustomobject]@{}
		$_.Attribute | % {
			$asset | Add-Member @{ $_.name = $_.InnerText }
		}
		$result += ,$asset		
	}
	$result
}

function Get-SingleAsset {
	param($xmlObject)
	$result = [pscustomobject]@{}
	$xmlObject.Asset.Attribute | % {
		$result | Add-Member @{ $_.name = $_.InnerText }
	}
	$result
}

function Invoke-Meta {
    if(Test-Path $metaFile) { return }
    $metaUrl = Get-MetaUrl
	Invoke-WebRequest (Get-MetaUrl) -OutFile $metaFile
}

function Get-MetaObject {
    Invoke-Meta
	[xml](Get-Content $metaFile)
}

function Get-AuthorizationHeader {
	#TODO: Make this like the amazon people did. Cache the credentials somewhere safe.
    $username = $user
    $password = $password
    $auth = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($username+":"+$password ))
    @{"AUTHORIZATION"=$auth}
}

function Get-V1Metamodel {
    $client = [pscustomobject] @{}    
    (Get-MetaObject).Meta.Assettype |
    % { 
		# TODO: avoid abstracts?
        $assetToken = $_.Token
		$assetObject = [pscustomobject] @{ Token = $assetToken}
                
        # attribute definition for the current asset
		($_).AttributeDefinition |
        % {			
			$assetObject | Add-Member @{$_.Name = $_.Name }
        }		
		$client | Add-Member @{ $assetToken= $assetObject}		
    }
    $client
}
Set-Alias vmeta Get-V1MetaModel

function Start-V1Query {    
    param(
    [Parameter(ValueFromPipeline=$true)]$asset, 
    [Parameter(Mandatory=$false,Position=0)]$id)
	
	$queryObject = [pscustomobject] @{ 
		Token = $asset.Token;
		ID = $id;
		SelectedFields = $null;
		WhereCondition = $null;
        Executed = $false
	}
	
	$queryObject
}
Set-Alias vquery Start-V1Query

function Invoke-V1Select {    
	param(
    [Parameter(ValueFromPipeline=$true)]$queryObject, 
    [Parameter(Mandatory=$true,Position=0)][string[]]$fields)
    
    if($queryObject.SelectedFields -ne $null) { return $queryObject }    
    $queryObject.SelectedFields = [string]::Join(",",$fields)
    $queryObject

}
Set-Alias vselect Invoke-V1Select

function ParseExpression {
    param($expression)
    #logical operators 
    #   -and -or 
    #   ';' '|'
    
    #comparison-operator 
    #   -eq -ne -lt -le -gt -ge
    #   '=' | '!=' | '<' | '<=' | '>' | '>='
}

function Invoke-V1Where {    
	param(
    [Parameter(ValueFromPipeline=$true)]$queryObject, 
    [Parameter(Mandatory=$true,Position=0)]$filter)
    
    $expresion = $filter.Ast.EndBlock.Extent.Text
    $queryObject
}
Set-Alias vwhere Invoke-V1Where

function Get-RequestUrl {
	param($queryObject)
    
    $url = (Get-RestUrl) + $queryObject.Token

	if($queryObject.Id -ne $null) {
		$url += "/$($queryObject.Id)"
	}
    
    $chainSymbol = "?"
    
    if($queryObject.SelectedFields -ne $null) {
        $url += "$($chainSymbol)sel=$($queryObject.SelectedFields)"
        $chainSymbol = "&"
    }    
    $url
}

function Invoke-V1Fetch {
	param([Parameter(ValueFromPipeline=$true)]$queryObject)
    
    if($queryObject.Executed -eq $true) { return }
	
	$url = Get-RequestUrl $queryObject
	
	$xmlObject = Invoke-RestMethod $url -Headers (Get-AuthorizationHeader)
	$queryObject.Executed = $true
	if($queryObject.Id -eq $null) {
		Get-MultipleAssets $xmlObject
	}
	else {
		Get-SingleAsset $xmlObject
	}
}
Set-Alias vfetch Invoke-V1Fetch

Export-ModuleMember -Function Get-V1MetaModel,Start-V1Query,Invoke-V1Select,Invoke-V1Where,Invoke-V1Fetch -Alias vmeta,vquery,vselect,vwhere,vfetch