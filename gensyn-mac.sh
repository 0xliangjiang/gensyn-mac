#!/bin/bash

# Exit on any error
set -e

# Print commands as they are executed
set -x

# Create and change to working directory
WORK_DIR="./rl-swarm"
if [ -d "$WORK_DIR" ]; then
    echo "Removing existing directory..."
    rm -rf "$WORK_DIR"
fi

# Clone the repository
echo "Cloning repository..."
git clone https://github.com/gensyn-ai/rl-swarm.git "$WORK_DIR"
cd "$WORK_DIR"

# Create and activate virtual environment
echo "Setting up Python virtual environment..."
python3 -m venv .venv
source .venv/bin/activate

# # Upgrade pip
# echo "Upgrading pip..."
# pip install --upgrade pip

# # Install dependencies
# echo "Installing dependencies..."
# pip install -r requirements.txt

# Setup .bashrc
echo "Setting up environment variables..."
if [ ! -f ~/.bashrc ]; then
    touch ~/.bashrc
fi

# Add environment variables to .bashrc
cat << EOF >> ~/.bashrc
export PATH="\$PATH:/usr/local/bin"
export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
export PYTHONPATH="\$PYTHONPATH:$WORK_DIR"
EOF

# Source the updated .bashrc
source ~/.bashrc

# Setup config directory
echo "Setting up configuration..."
CONFIG_DIR="hivemind_exp/configs/mac"
mkdir -p "$CONFIG_DIR"

# Backup existing config if it exists
if [ -f "$CONFIG_DIR/grpo-qwen-2.5-0.5b-deepseek-r1.yaml" ]; then
    mv "$CONFIG_DIR/grpo-qwen-2.5-0.5b-deepseek-r1.yaml" "$CONFIG_DIR/grpo-qwen-2.5-0.5b-deepseek-r1-backup.yaml"
fi

# Write new configuration
cat << EOF > "$CONFIG_DIR/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"
model_name_or_path: Gensyn/Qwen2.5-0.5B-Instruct
model_revision: main
torch_dtype: float32
attn_implementation: default
bf16: false
tf32: false
output_dir: runs/gsm8k/multinode/Qwen2.5-0.5B-Instruct-Gensyn-Swarm
dataset_id_or_path: 'openai/gsm8k'
max_steps: 50
per_device_train_batch_size: 1
gradient_accumulation_steps: 5
gradient_checkpointing: true
gradient_checkpointing_kwargs:
  use_reentrant: true
learning_rate: 5.0e-6
lr_scheduler_type: cosine
warmup_ratio: 0.1
beta: 0.001
max_prompt_length: 96
max_completion_length: 96
num_generations: 1
use_vllm: false
vllm_gpu_memory_utilization: 0.5
device: mlx_gpu
logging_strategy: steps
logging_steps: 10
report_to:
- tensorboard
save_strategy: steps
save_steps: 100
seed: 42
max_rounds: 10000
max_grad_norm: 0.5
EOF

echo "Environment setup complete!"
echo "To run the swarm, execute: ./run_rl_swarm.sh"

export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0 && ./run_rl_swarm.sh
