#!/bin/bash

# Check if VM IP address is provided
if [ -z "$1" ]; then
  echo "Usage: sudo ./ssh_and_run.sh <VM_IP_ADDRESS>"
  exit 1
fi

# Variables
VM_IP_ADDRESS="$1"
#ADMIN_USERNAME="azureuser"            # Replace with your VM's admin username
#ADMIN_PASSWORD="Operation@9999"       # Replace with your VM's admin password
ADMIN_USERNAME="evitey-test-01"
ADMIN_PASSWORD="evitey-test-01??" 
REPO_URL="https://github.com/rahulhm/evitey-deploy.git"
REPO_DIR="evitey-deploy"
SCRIPT_NAME="evitey.sh"

# Function to install sshpass if not already installed
install_sshpass() {
  if ! command -v sshpass &> /dev/null; then
    echo "sshpass not found. Installing sshpass..."
    sudo apt-get update
    sudo apt-get install -y sshpass
    if [ $? -ne 0 ]; then
      echo "Failed to install sshpass. Please install it manually."
      exit 1
    fi
    echo "sshpass installed successfully."
  else
    echo "sshpass is already installed."
  fi
}

# Install sshpass if needed
install_sshpass

# SSH into the VM and run commands
{
  # Remove old host key
  ssh-keygen -f "/root/.ssh/known_hosts" -R "$VM_IP_ADDRESS"

  # Add new host key
  ssh-keyscan -H "$VM_IP_ADDRESS" >> ~/.ssh/known_hosts
} || {
  echo "Failed to update known hosts. Exiting."
  exit 1
}

# SSH into the VM and run commands
sshpass -p "$ADMIN_PASSWORD" ssh -o StrictHostKeyChecking=no "$ADMIN_USERNAME@$VM_IP_ADDRESS" /bin/bash << EOF
  echo "Cloning repository..."
  if git clone "$REPO_URL"; then
    echo "Repository cloned successfully."
  else
    echo "Failed to clone repository."
    exit 1
  fi

  cd "$REPO_DIR"

  echo "Setting script permissions..."
  if sudo chmod +x "$SCRIPT_NAME"; then
    echo "Permissions set successfully."
  else
    echo "Failed to set permissions."
    exit 1
  fi

  echo "Running script..."
  if sudo ./"$SCRIPT_NAME"; then
    echo "Script executed successfully."
  else
    echo "Failed to execute script."
    exit 1
  fi
EOF
