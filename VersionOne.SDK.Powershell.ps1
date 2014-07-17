#TODO: The whole thing should be a module and we should only make public functions that require it
#TODO: Endpoints should be configurable

$metaFile = "meta.xml"

function Get-RestUrl {
    "https://www14.v1host.com/v1sdktesting/rest-1.v1/Data/"
}

function Get-MetaUrl {
    "https://www14.v1host.com/v1sdktesting/meta.v1/"
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
	Invoke-WebRequest (Get-MetaUrl) -OutFile $metaFile
}

function Get-MetaObject {
    Invoke-Meta
	[xml](Get-Content $metaFile)
}


function Get-AuthorizationHeader {
	#TODO: Make this like the amazon people did. Cache the credentials somewhere safe.
    $username = 'admin'
    $password = 'admin'
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

function Invoke-V1Select {    
	param(
    [Parameter(ValueFromPipeline=$true)]$queryObject, 
    [Parameter(Mandatory=$true,Position=0)][string[]]$fields)
    
    if($queryObject.SelectedFields -ne $null) { return $queryObject }    
    $queryObject.SelectedFields = [string]::Join(",",$fields)
    $queryObject

}

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

function Invoke-V1Query {
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

$s = (Get-V1Metamodel).Story

$r = ($s |
Start-V1Query 37741 |
Invoke-V1Select $s.Name, $s.ID, $s.ChangeDate |
#Invoke-V1Where { $s.Name -eq "SomeName" -and $s.AssetType -eq "someType" } |
Invoke-V1Query)

#$m = (Get-V1Metamodel).Member
#$members = $m |
#Start-V1Query |
#Invoke-V1Select $m.Username, $m.Email | 
#Invoke-V1Query


#https://www14.v1host.com/v1sdktesting/rest-1.v1/Data/Member
#?sel=Name,Email,DefaultRole.Name
#&where=OwnedWorkitems=%27Story:1071%27