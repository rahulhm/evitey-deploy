#!/bin/bash

# Set your resource group name and VM name
resource_group_name="mc-dev-env"
vm_name="catalog-service"

# Start the VM using az command
az vm start --resource-group $resource_group_name --name $vm_name

# Stop the VM using az command
az vm deallocate --resource-group $resource_group_name --name $vm_name
