#!/bin/bash

# Exit on any error
set -e

# Print commands as they are executed
set -x

# Check Python environment
echo "安装python3.11"
brew install python@3.11
echo "Python version: $(python3 --version)"

mkdir -p ~/Desktop/gensyn

# Clone the repository
echo "Cloning repository..."
git clone https://github.com/gensyn-ai/rl-swarm.git ~/Desktop/gensyn/rl-swarm
cd ~/Desktop/gensyn/rl-swarm

# Create and activate virtual environment
echo "Setting up Python virtual environment..."
python3.11 -m venv .venv


cd ~/Desktop/gensyn/rl-swarm  && touch auto.sh && chmod 777 auto.sh
# Write new configuration
cd ~/Desktop/gensyn/rl-swarm  && cat << EOF > "auto.sh"


EOF

cd ~/Desktop/gensyn/rl-swarm && sh auto.sh
