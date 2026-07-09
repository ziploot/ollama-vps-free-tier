#!/bin/bash
# ====================================================================
# 🦙 Ollama VPS Free-Tier 1-Click Auto-Installer/Uninstaller (Linux)
# Created by ZipLoot (https://ziploot.blogspot.com)
# ====================================================================

# Set colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0;37m' # No Color

clear
echo -e "${CYAN}======================================================${NC}"
echo -e "${GREEN}    🦙 Ollama VPS Free-Tier Setup Utility 🦙        ${NC}"
echo -e "${CYAN}======================================================${NC}"

# Check for root/sudo privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Please run this script with sudo or as root!${NC}"
    echo -e "Usage: curl -fsSL ... | sudo bash"
    exit 1
fi

# Main Menu
echo -e "Please select an action:"
echo -e "  [1] Install and Configure Ollama (with Swap & Remote API)"
echo -e "  [2] Uninstall Ollama and Clean Up (Remove models, swap & configs)"
echo -e "  [3] Exit"

MENU_CHOICE=""
while [[ ! "$MENU_CHOICE" =~ ^[1-3]$ ]]; do
    read -p "Select choice (1-3) [Default: 1]: " MENU_CHOICE
    MENU_CHOICE=${MENU_CHOICE:-1}
done

if [ "$MENU_CHOICE" -eq 3 ]; then
    echo -e "${YELLOW}Exiting.${NC}"
    exit 0
fi

# UNINSTALL ROUTINE
if [ "$MENU_CHOICE" -eq 2 ]; then
    echo -e "\n${YELLOW}[UNINSTALL] Starting uninstallation of Ollama and cleaning resources...${NC}"
    
    # 1. Stop and Disable Service
    if systemctl is-active --quiet ollama; then
        echo -e "[INFO] Stopping Ollama service..."
        sudo systemctl stop ollama
    fi
    if systemctl is-enabled --quiet ollama &>/dev/null; then
        echo -e "[INFO] Disabling Ollama service..."
        sudo systemctl disable ollama &>/dev/null
    fi

    # 2. Remove Systemd Service and Configuration
    echo -e "[INFO] Removing systemd service files..."
    sudo rm -f /etc/systemd/system/ollama.service
    sudo rm -rf /etc/systemd/system/ollama.service.d
    sudo systemctl daemon-reload

    # 3. Remove Binary
    if command -v ollama &> /dev/null; then
        OLLAMA_PATH=$(which ollama)
        echo -e "[INFO] Removing Ollama binary at ${OLLAMA_PATH}..."
        sudo rm -f "$OLLAMA_PATH"
    fi
    sudo rm -f /usr/local/bin/ollama
    sudo rm -f /usr/bin/ollama

    # 4. Remove Config and Models Data
    echo -e "[INFO] Deleting Ollama data directory (~/.ollama and /usr/share/ollama)..."
    sudo rm -rf /usr/share/ollama
    sudo rm -rf ~/.ollama
    sudo rm -rf /home/*/.ollama
    
    # Remove user
    if id "ollama" &>/dev/null; then
        echo -e "[INFO] Removing ollama system user..."
        sudo userdel ollama &>/dev/null
    fi

    # 5. Remove Swap Partition (if created by us)
    if [ -f /swapfile ]; then
        read -p "A swapfile (/swapfile) was detected. Do you want to disable and delete it? [Y/n]: " SWAP_DEL
        SWAP_DEL=${SWAP_DEL:-Y}
        if [[ "$SWAP_DEL" =~ ^[Yy]$ ]]; then
            echo -e "[INFO] Deactivating swap file..."
            sudo swapoff /swapfile
            echo -e "[INFO] Removing swap file..."
            sudo rm -f /swapfile
            echo -e "[INFO] Removing swap entry from /etc/fstab..."
            sudo sed -i '\|/swapfile|d' /etc/fstab
            echo -e "${GREEN}[SUCCESS] Swap partition successfully removed.${NC}"
        fi
    fi

    echo -e "\n${GREEN}======================================================${NC}"
    echo -e "${GREEN}🏆 Ollama Uninstalled & System Cleaned Successfully! 🏆${NC}"
    echo -e "${GREEN}======================================================${NC}"
    exit 0
fi

# INSTALL ROUTINE
# Pre-flight Check: Supported OS
if ! command -v apt-get &> /dev/null && ! command -v yum &> /dev/null; then
    echo -e "${RED}[ERROR] Package manager not supported. This installer requires APT (Ubuntu/Debian) or YUM (CentOS/RHEL).${NC}"
    exit 1
fi

# FRONT-LOAD INPUTS & VALIDATION LOOP
echo -e "\n${YELLOW}[STEP 1/4] Front-loading configurations & Model Selection${NC}"
echo -e "Please select the quantized LLM you want to install:"
echo -e "  [1] Qwen 2.5 Coder 1.5B (Recommended - High accuracy coding/reasoning) [980MB RAM]"
echo -e "  [2] TinyLlama 1.1B (Ultra lightweight & fast generation) [680MB RAM]"
echo -e "  [3] Llama 3.2 1B (Meta's lightweight model) [740MB RAM]"
echo -e "  [4] Custom Model Name (e.g., gemma:2b, deepseek-coder:1.3b)"

MODEL_CHOICE=""
while [[ ! "$MODEL_CHOICE" =~ ^[1-4]$ ]]; do
    read -p "Select choice (1-4) [Default: 1]: " MODEL_CHOICE
    MODEL_CHOICE=${MODEL_CHOICE:-1}
done

MODEL_NAME=""
if [ "$MODEL_CHOICE" -eq 1 ]; then
    MODEL_NAME="qwen2.5-coder:1.5b"
elif [ "$MODEL_CHOICE" -eq 2 ]; then
    MODEL_NAME="tinyllama"
elif [ "$MODEL_CHOICE" -eq 3 ]; then
    MODEL_NAME="llama3.2:1b"
elif [ "$MODEL_CHOICE" -eq 4 ]; then
    while [ -z "$MODEL_NAME" ]; do
        read -p "Enter custom model name (from ollama.com/library): " MODEL_NAME
    done
fi

# Swap Space configuration choice
read -p "Configure a 2GB Swap space? (Highly recommended for 1GB VPS) [Y/n]: " SWAP_CONFIRM
SWAP_CONFIRM=${SWAP_CONFIRM:-Y}

# Remote access choice
read -p "Expose Ollama API to public internet (0.0.0.0:11434)? [Y/n]: " EXPOSE_CONFIRM
EXPOSE_CONFIRM=${EXPOSE_CONFIRM:-Y}

echo -e "\n${GREEN}[INFO] All configurations collected! Starting installation...${NC}\n"

# STEP 2: Configure Swap file
if [[ "$SWAP_CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[STEP 2/4] Configuring Swap partition...${NC}"
    # Check current swap size in MB
    CURRENT_SWAP=$(free -m | awk '/^Swap:/{print $2}')
    if [ "$CURRENT_SWAP" -gt 1500 ]; then
        echo -e "${GREEN}[SUCCESS] Swap partition of ${CURRENT_SWAP}MB already exists. Skipping creation.${NC}"
    else
        echo -e "[INFO] Setting up 2GB swap space to prevent memory crashes..."
        # If /swapfile exists, delete it first to reallocate
        if [ -f /swapfile ]; then
            sudo swapoff /swapfile &>/dev/null
            sudo rm -f /swapfile
        fi
        
        sudo fallocate -l 2G /swapfile
        if [ $? -ne 0 ]; then
            echo -e "${YELLOW}[WARN] fallocate failed. Trying dd...${NC}"
            sudo dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
        fi
        
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        
        # Check if already in fstab
        if ! grep -q "/swapfile" /etc/fstab; then
            echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
        fi
        echo -e "${GREEN}[SUCCESS] 2GB Swap space successfully created and enabled!${NC}"
    fi
else
    echo -e "${YELLOW}[STEP 2/4] Skipping Swap configuration.${NC}"
fi

# STEP 3: Install Ollama
echo -e "\n${YELLOW}[STEP 3/4] Installing Ollama service...${NC}"
if command -v ollama &> /dev/null; then
    echo -e "${GREEN}[SUCCESS] Ollama is already installed!${NC}"
else
    echo -e "[INFO] Fetching and running the official Ollama setup binary..."
    curl -fsSL https://ollama.com/install.sh | sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERROR] Ollama installation failed! Please check your network connectivity.${NC}"
        exit 1
    fi
fi

# STEP 4: Configure external exposure (Systemd override)
if [[ "$EXPOSE_CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}[STEP 4/4] Exposing Ollama API host...${NC}"
    OVERRIDE_DIR="/etc/systemd/system/ollama.service.d"
    sudo mkdir -p "$OVERRIDE_DIR"
    echo -e "[Service]\nEnvironment=\"OLLAMA_HOST=0.0.0.0\"" | sudo tee "$OVERRIDE_DIR/override.conf" > /dev/null
    
    echo -e "[INFO] Reloading systemd daemon and restarting Ollama service..."
    sudo systemctl daemon-reload
    sudo systemctl restart ollama
    echo -e "${GREEN}[SUCCESS] Ollama exposed to 0.0.0.0:11434 successfully!${NC}"
else
    echo -e "\n${YELLOW}[STEP 4/4] Restarting local-only Ollama service...${NC}"
    sudo systemctl restart ollama
fi

# Run Model Setup
echo -e "\n${YELLOW}[MODEL] Pulling & starting model: ${MODEL_NAME}...${NC}"
echo -e "[INFO] This might take a few minutes depending on your VPS network connection..."
ollama pull "$MODEL_NAME"

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}======================================================${NC}"
    echo -e "${GREEN}🏆 Ollama VPS Auto-Setup Completed Successfully! 🏆${NC}"
    echo -e "${GREEN}======================================================${NC}"
    
    # Get Public IP address
    PUBLIC_IP=$(curl -s https://api.ipify.org || curl -s https://ifconfig.me || echo "[YOUR_VPS_IP]")
    
    echo -e "\n${CYAN}🚀 Your Ollama endpoint is ready!${NC}"
    if [[ "$EXPOSE_CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "API Endpoint: ${GREEN}http://${PUBLIC_IP}:11434${NC}"
        echo -e "\n🔥 Test it from your local machine using this command:"
        echo -e "--------------------------------------------------------"
        echo -e "curl -X POST http://${PUBLIC_IP}:11434/api/generate -d '{"
        echo -e "  "model": "${MODEL_NAME}","
        echo -e "  "prompt": "Why is the sky blue? Answer in 1 sentence.","
        echo -e "  "stream": false"
        echo -e "}'"
        echo -e "--------------------------------------------------------"
    else
        echo -e "API Endpoint (Local Only): ${GREEN}http://127.0.0.1:11434${NC}"
        echo -e "\n🔥 Test it locally inside your VPS using:"
        echo -e "--------------------------------------------------------"
        echo -e "curl -X POST http://127.0.0.1:11434/api/generate -d '{"
        echo -e "  "model": "${MODEL_NAME}","
        echo -e "  "prompt": "Why is the sky blue? Answer in 1 sentence.","
        echo -e "  "stream": false"
        echo -e "}'"
        echo -e "--------------------------------------------------------"
    fi
else
    echo -e "${RED}[ERROR] Failed to pull model ${MODEL_NAME}. Check if the model name is correct.${NC}"
    exit 1
fi
