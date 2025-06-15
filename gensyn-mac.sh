#!/bin/bash

# Exit on any error
set -e

# Print commands as they are executed
set -x

# Check Python environment
echo "Checking Python environment..."
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
source .venv/bin/activate

# Backup existing config if it exists
if [ -f "~/Desktop/gensyn/rl-swarm/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml" ]; then
    mv "~/Desktop/gensyn/rl-swarm/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml" "~/Desktop/gensyn/rl-swarm/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1-backup.yaml"
fi

# Write new configuration
cat << EOF > "~/Desktop/gensyn/rl-swarm/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"
# Model arguments
model_revision: main
torch_dtype: float16
attn_implementation: default
bf16: false
tf32: false

# Dataset arguments
dataset_id_or_path: 'openai/gsm8k'

# Training arguments
max_steps: 50 # Original 450
gradient_accumulation_steps: 4
gradient_checkpointing: true
gradient_checkpointing_kwargs:
  use_reentrant: false
learning_rate: 5.0e-6 # 1.0e-6 as in the deepseek math paper 5-e7 from https://hijkzzz.notion.site/unraveling-rlhf-and-its-variants-engineering-insights#147d9a33ecc9806090f3d5c749d31f05
lr_scheduler_type: cosine
warmup_ratio: 0.03

# GRPO arguments
use_vllm: false
num_generations: 2
per_device_train_batch_size: 2
beta: 0.001 # 0.04 as in the deepseek math paper 0.001 from https://hijkzzz.notion.site/unraveling-rlhf-and-its-variants-engineering-insights#147d9a33ecc9806090f3d5c749d31f05
max_prompt_length: 96
max_completion_length: 96

# Logging arguments
logging_strategy: steps
logging_steps: 2
report_to:
- wandb
save_strategy: "steps"
save_steps: 25
seed: 42

# Script arguments
max_rounds: 10000
max_grad_norm: 0.5

# Model-specific arguments
model_name_or_path: unsloth/Qwen2.5-0.5B-Instruct
output_dir: runs/gsm8k/multinode/Qwen2.5-0.5B-Instruct-Gensyn-Swarm

EOF

echo "Environment setup complete!"

export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0 && ./run_rl_swarm.sh
