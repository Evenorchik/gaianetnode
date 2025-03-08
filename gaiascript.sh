#!/bin/bash
set -e
set -o pipefail

# Text color
CYAN='\033[0;36m'
NC='\033[0m'

# Clear screen
clear

# Check if curl is installed and install if missing
if ! command -v curl &> /dev/null; then
    sudo apt update
    sudo apt install curl -y
fi

# Check if psmisc is installed (for fuser)
if ! command -v fuser &> /dev/null; then
    sudo apt install psmisc -y
fi

# Display logo
curl -s https://raw.githubusercontent.com/Evenorchik/evenorlogo/main/evenorlogo.sh | bash

# Function to display the menu
print_menu() {

    echo -e "${CYAN}Available actions:\n"
    echo -e "${CYAN}[1] -> Install node${NC}"
    echo -e "${CYAN}[2] -> Start farming script${NC}"
    echo -e "${CYAN}[3] -> Update node${NC}"
    echo -e "${CYAN}[4] -> Node info${NC}"
    echo -e "${CYAN}[5] -> Delete node${NC}"
    echo -e "${CYAN}[6] -> Delete farming script${NC}\n"
}

# Display menu
print_menu

# Prompt user for choice
echo -e "${CYAN}Enter action number [1-6]:${NC} "
read -p "-> " choice

case $choice in
    1)
        echo -e "\n${CYAN}Installing Gaia node...${NC}\n"

        echo -e "${CYAN}[1/6] -> Updating system...${NC}"
        sudo apt update && sudo apt upgrade -y
        sudo apt install -y python3-pip python3-dev python3-venv curl git
        sudo apt install -y build-essential
        pip3 install aiohttp

        echo -e "${CYAN}[2/6] -> Freeing port 8080...${NC}"
        sudo fuser -k 8080/tcp
        sleep 3

        echo -e "${CYAN}[3/6] -> Installing Gaianet...${NC}"
        curl -sSfL 'https://github.com/GaiaNet-AI/gaianet-node/releases/latest/download/install.sh' | bash
        sleep 2
        
        echo -e "${CYAN}[4/6] -> Setting environment variables...${NC}"
        echo "export PATH=\$PATH:$HOME/gaianet/bin" >> "$HOME/.bashrc"
        # Immediately export the new PATH in the current session
        export PATH="$PATH:$HOME/gaianet/bin"
        sleep 10
        
        if ! command -v gaianet &> /dev/null; then
            echo -e "${CYAN}Error: gaianet not found! $HOME/gaianet/bin not added to PATH.${NC}"
            exit 1
        fi

        echo -e "${CYAN}[5/6] -> Initializing node...${NC}"
        gaianet init --config https://raw.githubusercontent.com/GaiaNet-AI/node-configs/main/qwen2-0.5b-instruct/config.json  

        echo -e "${CYAN}[6/6] -> Starting node...${NC}"
        gaianet start

        echo -e "\n${CYAN}Installation completed successfully!${NC}\n"
        sleep 2
        ;;

    2)
        echo -e "\n${CYAN}Starting Gaia bot...${NC}\n"

        echo -e "${CYAN}[1/4] -> Creating configuration...${NC}"
        mkdir -p ~/gaia-bot
        cd ~/gaia-bot
        
        # Add diverse queries to phrases.txt
        cat > phrases.txt <<EOF
"How can emerging technologies reshape urban mobility?"
"What innovations in renewable energy are on the horizon?"
"How might advances in biotechnology redefine healthcare?"
"What role does cybersecurity play in future digital economies?"
"How could smart city designs improve quality of life?"
"In what ways can space technology drive sustainable solutions?"
"How does digital transformation influence global trade?"
"Can autonomous systems revolutionize logistics and transportation?"
"What future challenges could arise from quantum computing?"
"How will next-generation communication networks impact society?"
EOF

        # Add roles to roles.txt
        echo -e "system\nuser\nassistant\ntool" > roles.txt

        echo -e "${CYAN}[2/4] -> Downloading bot script...${NC}"
        curl -L https://raw.githubusercontent.com/Evenor_soft/NodeRunnerScripts/main/gaia_bot.py -o gaia_bot.py

        echo -e "${CYAN}[3/4] -> Configuring bot...${NC}"
        echo -e "${CYAN}Enter your node address:${NC}"
        read -p "-> " NODE_ID
        
        if [ -z "$NODE_ID" ]; then
            echo -e "${CYAN}Error: Node address cannot be empty.${NC}"
            exit 1
        fi
        
        sed -i "s|\$NODE_ID|${NODE_ID}|g" gaia_bot.py

        USERNAME=$(whoami)
        HOME_DIR=$(eval echo ~$USERNAME)

        echo -e "${CYAN}[4/4] -> Setting up and starting service...${NC}"
        # Use sudo tee to create the service file
        cat <<EOF | sudo tee /etc/systemd/system/gaia-bot.service
[Unit]
Description=Gaia Bot
After=network.target

[Service]
Environment=NODE_ID=${NODE_ID}
Environment=RETRY_COUNT=3
Environment=RETRY_DELAY=5
Environment=TIMEOUT=60
ExecStart=/usr/bin/python3 ${HOME_DIR}/gaia-bot/gaia_bot.py
Restart=always
User=${USERNAME}
Group=${USERNAME}
WorkingDirectory=${HOME_DIR}/gaia-bot

[Install]
WantedBy=multi-user.target
EOF

        # Start the bot
        sudo systemctl daemon-reload
        sleep 1
        sudo systemctl enable gaia-bot.service
        sudo systemctl start gaia-bot.service

        echo -e "\n${CYAN}Bot started successfully!${NC}"
        echo -e "\n${CYAN}To view logs, use the command:${NC}"
        echo -e "${CYAN}sudo journalctl -u gaia-bot -f${NC}\n"
        
        sudo journalctl -u gaia-bot -f
        ;;

    3)
        echo -e "\n${CYAN}You have the latest version of Gaia node installed.${NC}\n"
        ;;

    4)
        echo -e "\n${CYAN}Node information:${NC}\n"
        gaianet info
        ;;

    5)
        echo -e "\n${CYAN}Deleting Gaia node...${NC}\n"
        gaianet stop
        rm -rf ~/gaianet
        echo -e "\n${CYAN}Node deleted successfully${NC}\n"
        sleep 2
        ;;

    6)
        echo -e "\n${CYAN}Deleting Gaia bot...${NC}\n"
        sudo systemctl stop gaia-bot.service
        sudo systemctl disable gaia-bot.service
        sudo rm /etc/systemd/system/gaia-bot.service
        sudo systemctl daemon-reload
        sleep 1
        rm -rf ~/gaia-bot
        echo -e "\n${CYAN}Bot deleted successfully${NC}\n"
        sleep 2
        ;;

    *)
        echo -e "\n${CYAN}Error: Invalid choice!${NC}\n"
        ;;
esac
