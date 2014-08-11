﻿# TODO: this help format does not work for modules, but the .EXAMPLES are valid examples for using this module's code.
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

#$metaFile = [IO.Path]::GetTempFileName()

$metaFile="meta.xml"

function Get-RestUrl {
    "$baseUrl/rest-1.v1/Data/"
}

function Get-MetaUrl {
    "$baseUrl/meta.v1/"
}

#TODO: refactor these 2 functions
function Get-MultipleAssets {
	param($xmlObject)	
	$result = @()
	$xmlObject.Assets.Asset | % {
		$asset = [pscustomobject]@{}
        $asset | Add-Member @{ OID = $_.id}
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
    $result | Add-Member @{ OID = $xmlObject.Asset.id}
	$xmlObject.Asset.Attribute | % {
		$result | Add-Member @{ $_.name = $_.InnerText }
	}
	$result
}

function Get-MetaObject {
    if(-not (Test-Path $metaFile)) {
        Invoke-WebRequest (Get-MetaUrl) -OutFile $metaFile
    }    
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
    $metaModel = [pscustomobject] @{}    
    (Get-MetaObject).Meta.Assettype |
    % { 
		# TODO: avoid abstracts?
        $assetToken = $_.Token
		$assetObject = [pscustomobject] @{ Token = $assetToken}
		$metaModel | Add-Member @{ $assetToken= $assetObject}
                
        # attribute definition for the current asset
		($_).AttributeDefinition |
        % {			
			$assetObject | Add-Member @{$_.Name = $_.Name }
			#$_.attributeType
			#$_.isreadonly
			#$_.isrequired
			#$_.ismultivalue
        }
		
		# operations:
		if($_.Operation -eq $null) {return}
		$assetObject | Add-Member @{Operation = [pscustomobject] @{} } -Force		
		$_.Operation | % {
			$assetObject.Operation | Add-Member @{ $_.Name = $_.Name }		
		}
    }
    $metaModel
}
Set-Alias vmeta Get-V1MetaModel

function Start-V1Query {    
    param(
    [Parameter(ValueFromPipeline=$true)]$asset, 
    [Parameter(Mandatory=$false,Position=0)]$id)
	
	$queryObject = [pscustomobject] @{ 
		Token = $asset.Token;
		ID = $id;
		SelectExpression = $null;
		WhereExpression = $null;        
        Executed = $false		
	}
	
	$queryObject
}
Set-Alias vquery Start-V1Query

function Invoke-V1Select {    
	param(
    [Parameter(ValueFromPipeline=$true)]$queryObject, 
    [Parameter(Mandatory=$true,Position=0)][string[]]$fields)
    
    if($queryObject.SelectExpression -ne $null) { return $queryObject }    
    $queryObject.SelectExpression = [string]::Join(",",$fields)
    $queryObject

}
Set-Alias vselect Invoke-V1Select

$tokensTable = @{ 
    'And' = ';';
	'Or' = '|';
	'Ieq' = '=';
	'Ine' = '!=';
	'Ilt'= '<';
    'Ile'= '<=';
	'Igt'= '>';
	'Ige'= '>='
}

function ParsePSExpression {
    param($expression)
    $psTokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($expression, [ref]$psTokens, [ref]$parseErrors)
    
    $tokens = @()
    $previousToken = $null
    $psTokens | % {        
        if($_.Kind -eq 'Dot' -and $previousToken -eq 'Identifier') {$tokens += '.'}
        elseif(($_.Kind -eq 'Identifier') -or ($_.Kind -eq 'StringLiteral')){ $tokens += $_.Text }
        elseif($tokensTable.ContainsKey([string]$_.Kind)){ $tokens+=($tokensTable[[string]$_.Kind]) }
        $previousToken = $_.Kind
    }
    $restExpression = [string]::Join("",$tokens)
	$restExpression
}

function Invoke-V1Where {    
	param(
    [Parameter(ValueFromPipeline=$true)]$queryObject, 
    [Parameter(Mandatory=$true,Position=0)]$filter)
    
    $psExpression = $filter.Ast.EndBlock.Extent.Text
	$queryObject.WhereExpression = ParsePSExpression $psExpression
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
    
    if($queryObject.SelectExpression -ne $null) {
        $url += "$($chainSymbol)sel=$($queryObject.SelectExpression)"
        $chainSymbol = "&"
    }
	
	if($queryObject.WhereExpression -ne $null) {
		$url += "$($chainSymbol)where=$($queryObject.WhereExpression)"
        $chainSymbol = "&"	
	}
    
	Write-Host $url
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

function Invoke-V1Operation {
    param(
        [Parameter(ValueFromPipeline=$true,Mandatory=$true)]$asset,
        [Parameter(Mandatory=$true,Position=0)]$operation)
    
    
    $parts = $asset.OID.Split(':');
    $token = $parts[0]
    $id = $parts[1]

    $url = (Get-RestUrl) +  "$token/$id" + '?op=' + $operation
    
    echo $url
    Invoke-WebRequest -Method Post -Uri $url -Headers (Get-AuthorizationHeader)    
}
Set-Alias vop Invoke-V1Operation

Export-ModuleMember -Function Get-V1MetaModel,Start-V1Query,Invoke-V1Select,Invoke-V1Where,Invoke-V1Fetch,Invoke-V1Operation -Alias vmeta,vquery,vselect,vwhere,vfetch,vop