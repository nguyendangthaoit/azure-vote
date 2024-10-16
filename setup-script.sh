#!/bin/bash

# Variables
resourceGroup="acdnd-c4-project"
location="westus"
osType="Ubuntu2204"
vmssName="udacity-vmss"
adminName="udacityadmin"
storageAccount="udacitydiag$RANDOM"
bePoolName="$vmssName-bepool"
lbName="$vmssName-lb"
lbRule="$lbName-network-rule"
nsgName="$vmssName-nsg"
vnetName="$vmssName-vnet"
subnetName="$vnetName-subnet"
probeName="tcpProbe"
vmSize="Standard_B1s"
storageType="Standard_LRS"

# Create resource group
echo "STEP 0 - Creating resource group $resourceGroup..."

az group create \
--name $resourceGroup \
--location $location \
--verbose

echo "Resource group created: $resourceGroup"

# Create Storage account
echo "STEP 1 - Creating storage account $storageAccount"

az storage account create \
--name $storageAccount \
--resource-group $resourceGroup \
--location $location \
--sku Standard_LRS

echo "Storage account created: $storageAccount"

# Create Network Security Group
echo "STEP 2 - Creating network security group $nsgName"

az network nsg create \
--resource-group $resourceGroup \
--name $nsgName \
--verbose

echo "Network security group created: $nsgName"

# Create Virtual Network and Subnet
echo "STEP 3 - Creating virtual network $vnetName and subnet $subnetName"

az network vnet create \
  --resource-group $resourceGroup \
  --name $vnetName \
  --subnet-name $subnetName \
  --verbose

echo "Virtual network and subnet created: $vnetName, $subnetName"

# Create VM Scale Set
echo "STEP 4 - Creating VM scale set $vmssName"

az vmss create \
  --resource-group $resourceGroup \
  --name $vmssName \
  --image $osType \
  --vm-sku $vmSize \
  --subnet $subnetName \
  --vnet-name $vnetName \
  --backend-pool-name $bePoolName \
  --storage-sku $storageType \
  --load-balancer $lbName \
  --custom-data cloud-init.txt \
  --upgrade-policy-mode automatic \
  --admin-username $adminName \
  --generate-ssh-keys \
  --verbose 

echo "VM scale set created: $vmssName"

# Associate NSG with VMSS subnet
echo "STEP 5 - Associating NSG: $nsgName with subnet: $subnetName"

az network vnet subnet update \
--resource-group $resourceGroup \
--name $subnetName \
--vnet-name $vnetName \
--network-security-group $nsgName \
--verbose

echo "NSG: $nsgName associated with subnet: $subnetName"

# Create Health Probe
echo "STEP 6 - Creating health probe $probeName"

az network lb probe create \
  --resource-group $resourceGroup \
  --lb-name $lbName \
  --name $probeName \
  --protocol tcp \
  --port 80 \
  --interval 5 \
  --threshold 2 \
  --verbose

echo "Health probe created: $probeName"

# Remove existing conflicting load balancer rule if it exists
echo "STEP 7 - Removing existing conflicting load balancer rule if it exists"

az network lb rule delete \
  --resource-group $resourceGroup \
  --lb-name $lbName \
  --name $lbRule \
  --verbose

echo "Existing conflicting load balancer rule removed: $lbRule"

# Create Network Load Balancer Rule
echo "STEP 7 - Creating network load balancer rule $lbRule"

az network lb rule create \
  --resource-group $resourceGroup \
  --name $lbRule \
  --lb-name $lbName \
  --probe-name $probeName \
  --backend-pool-name $bePoolName \
  --backend-port 80 \
  --frontend-ip-name loadBalancerFrontEnd \
  --frontend-port 80 \
  --protocol tcp \
  --verbose

echo "Network load balancer rule created: $lbRule"


# Add port 80 to inbound rule NSG
echo "STEP 8 - Adding port 80 to NSG $nsgName"

az network nsg rule create \
--resource-group $resourceGroup \
--nsg-name $nsgName \
--name Port_80 \
--destination-port-ranges 80 \
--direction Inbound \
--priority 100 \
--verbose

echo "Port 80 added to NSG: $nsgName"

# Add port 22 to inbound rule NSG
echo "STEP 9 - Adding port 22 to NSG $nsgName"

az network nsg rule create \
--resource-group $resourceGroup \
--nsg-name $nsgName \
--name Port_22 \
--destination-port-ranges 22 \
--direction Inbound \
--priority 110 \
--verbose

echo "Port 22 added to NSG: $nsgName"

# Adding Custom Script Extension to deploy the app from GitHub
az vmss extension set \
  --resource-group $resourceGroup \
  --vmss-name $vmssName \
  --name CustomScript \
  --publisher Microsoft.Azure.Extensions \
  --settings '{"fileUris":["https://github.com/nguyendangthaoit/azure-vote/tree/main/azure-vote/deploy.sh"],"commandToExecute":"bash deploy.sh"}' \
  --verbose

echo "Custom script extension applied to VMSS to deploy the Flask app from GitHub."


echo "VMSS script completed!"
