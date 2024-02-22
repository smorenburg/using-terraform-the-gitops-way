# Astro

## Deploying the resources

**Step 1:** Connect to Azure and set the context. Replace `subscriptionId` with the subscription identifier.

```powershell
Connect-AzAccount
```

```powershell
Set-AzContext <subscriptionId>
```

**Step 2:** Create the storage account for the Terraform state. Copy the storage account name.

```powershell
./scripts/New-StorageAccount.ps1
```

**Step 3:** Set the variables. Replace `storage_account` with the storage account name.

```bash
export STORAGE_ACCOUNT=<storage_account>
````

```bash
export APP="nordcloud"
export LOCATION="northeurope"
export RESOURCE_GROUP="rg-tfstate-nordcloud-neu"
````

```bash
export TF_VAR_app=${APP}
export TF_VAR_location=${LOCATION}
```

**Step 4:** Initialize Terraform.

```bash
cd terraform && \
terraform init \
  -backend-config="storage_account_name=${STORAGE_ACCOUNT}" \
  -backend-config="resource_group_name=${RESOURCE_GROUP}" \
  -backend-config="key=${LOCATION}.tfstate"
````

**Step 5:** Deploy the resources.

```bash
terraform apply -auto-approve
```

**Step 6:** Connect to the cluster.

**Step 7:** Install the Flux CLI.

```bash
brew install fluxcd/tap/flux
```

**Step 8:** Create a GitHub personal access token with the `repo` scope.

**Step 9:** Set the variable. Replace `gh_token` with the personal access token.

```bash
export GITHUB_TOKEN=<gh_token>
````

**Step 10:** Bootstrap Flux.

```bash
flux bootstrap github \
  --owner=smorenburg \
  --repository=using-terraform-the-gitops-way-source \
  --branch=main \
  --path=clusters \
  --personal \
  --private=false
```
