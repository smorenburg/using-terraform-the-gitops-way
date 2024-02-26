$resourceGroupName = "rg-state-nc-neu"
$location = "northeurope"
$storageAccountSuffix = "stnc"
$random = -Join ("0123456789abcdef".ToCharArray() | Get-Random -Count 4 | ForEach-Object { [char]$PSItem })
$storageAccountName = $storageAccountSuffix + $random

New-AzResourceGroup -Name $resourceGroupName -Location $location

$account = @{
    ResourceGroupName = $resourceGroupName
    Name              = $storageAccountName
    Location          = $location
    SkuName           = "Standard_RAGRS"
    MinimumTlsVersion = "TLS1_2"
}

New-AzStorageAccount @account

$context = New-AzStorageContext -StorageAccountName $storageAccountName -UseConnectedAccount
New-AzStorageContainer -Name tfstate -Context $context