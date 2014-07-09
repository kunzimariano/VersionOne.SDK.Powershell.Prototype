#TODO: The whole thing should be a module and we should only make public functions that require it
#TODO: Endpoints should be configurable

$metaFile = "meta.xml"

function Get-RestUrl {
    "https://www14.v1host.com/v1sdktesting/rest-1.v1/Data/"
}

function Get-MetaUrl {
    "https://www14.v1host.com/v1sdktesting/meta.v1/"
}

function Get-RequestUrl {
	param($token,$id)
	
	if($id -eq $null) {
		return ((Get-RestUrl) + $this.Token)
	}
	((Get-RestUrl) + $this.Token + "/$id")
	
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

$GetAsset = {
	param($id)
	
	$url = Get-RequestUrl $this.Token $id
	
	$xmlObject = Invoke-RestMethod $url -Headers (Get-AuthorizationHeader)
	if($id -eq $null) {
		Get-MultipleAssets $xmlObject
	}
	else {
		Get-SingleAsset $xmlObject
	}
}

function Get-Meta {
#saving the file for the moment to avoid requesting all the time
	Invoke-WebRequest (Get-MetaUrl) -OutFile $metaFile
#   Invoke-RestMethod (Get-MetaUrl)
}

function Get-AuthorizationHeader {
	#TODO: Make this like the amazon people did. Cache the credentials somewhere safe.
    $username = 'admin'
    $password = 'admin'
    $auth = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($username+":"+$password ))
    @{"AUTHORIZATION"=$auth}
}

function Get-MetaObject {
	[xml](Get-Content $metaFile)
}

# At the current state this creates and object with every asset and their properties/attributes.
# The idea of having every attribute is to use that to build queries so we don't have to remember them, 
# not sure if that is what we will end up doing.
# TODO: Based on the operations available for that asset we can add the proper functions that can handle that operations
function Get-Client {
    $client = [pscustomobject] @{}    
    (Get-MetaObject).Meta.Assettype | 
    % { 
		# TODO: avoid abstracts?
        $assetToken = $_.Token
		$assetObject = [pscustomobject] @{ Token = $assetToken}
                
        # attribute definition for the current asset
		($_).AttributeDefinition |
        % {
			$assetObject | Add-Member @{$_.Name = [pscustomobject]@{} }
        }
		$assetObject | Add-Member -MemberType ScriptMethod -Name GetAsset -Value $GetAsset
		$client | Add-Member @{ $assetToken= $assetObject}		
    }
    $client
}
# Comment Get-Meta after you get the xml once
Get-Meta
$c = Get-Client
$story = $c.Story.GetAsset(37741)
$members =  $c.Member.GetAsset()



# I use this so i can see the whole object in the variable inspector
#$meta = Get-MetaObject


## Ignore things after this point

#function Get-Select {
#    param([String[]]$fields)
#    
#    '?sel=' + [string]::Join( ',',$fields)
#}
#
#function Get-Where {
#}
#
#function Get-Url {
#    param(
#    [string]$asset,
#    [string[]]$fields)    
#    
#    (Get-RestUrl) + $asset + (Get-Select $fields)
#}

#function Invoke-Query {
#    param(
#    [string]$asset,
#    [string[]]$fields)
#    
#    $url = Get-Url $asset $fields
#    $header = Get-AuthorizationHeader
#    
#    $result = Invoke-WebRequest -Method Get -Uri $url -Headers $header
#}

