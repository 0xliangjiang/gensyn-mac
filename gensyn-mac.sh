#!/bin/bash
set -euo pipefail

if ! command -v brew &> /dev/null; then
    echo "Homebrew 未安装，正在安装..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || error "Homebrew 安装失败"

    # 添加到 shell 配置文件（根据芯片架构判断路径）
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    echo "Homebrew 已安装"
fi

# Check Python environment
echo "安装python3.11"
brew install python@3.11

mkdir -p ~/Desktop/gensyn

# Clone the repository
echo "Cloning repository..."
git clone https://github.com/gensyn-ai/rl-swarm.git ~/Desktop/gensyn/rl-swarm
cd ~/Desktop/gensyn/rl-swarm

# Create and activate virtual environment
echo "Setting up Python virtual environment..."
python3.11 -m venv .venv


# 创建新脚本（使用单引号防止变量展开）
cd ~/Desktop/gensyn/rl-swarm && cat << 'EOF' > "auto.sh"
#!/bin/bash

# Mac M4 自动监控重启脚本
# 基于最新 run_rl_swarm.sh 的配置，自动化交互参数
# 监控进程状态，自动重启

set -euo pipefail

# 配置参数
RESTART_DELAY=30
CHECK_INTERVAL=10
LOG_FILE="$PWD/auto_monitor.log"
PID_FILE="$PWD/training.pid"

# 默认参数配置（基于最新 run_rl_swarm.sh）
DEFAULT_HF_PUSH="N"             # 不推送到 HuggingFace Hub
DEFAULT_MODEL_NAME="Gensyn/Qwen2.5-0.5B-Instruct"           # 使用默认模型（留空）

# 颜色输出
GREEN="\033[32m"
BLUE="\033[34m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

# 重要信息日志（显示在控制台并记录到文件）
log_important() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

echo_green() {
    echo -e "${GREEN}$1${RESET}"
}

echo_blue() {
    echo -e "${BLUE}$1${RESET}"
}

echo_red() {
    echo -e "${RED}$1${RESET}"
    log_important "$1"
}

echo_yellow() {
    echo -e "${YELLOW}$1${RESET}"
    log_important "$1"
}

# 清理函数
cleanup() {
    echo_yellow "🛑 正在停止监控..."
    
    # 终止训练进程
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo_yellow "终止训练进程 PID: $pid"
            kill -TERM "$pid" 2>/dev/null || true
            sleep 5
            if ps -p "$pid" > /dev/null 2>&1; then
                kill -KILL "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "$PID_FILE"
    fi
    
    # 清理相关进程
    pkill -f "swarm_launcher.py" 2>/dev/null || true
    pkill -f "run_rl_swarm.sh" 2>/dev/null || true
    pkill -f "yarn start" 2>/dev/null || true
    
    echo_green "✅ 监控已停止"
    exit 0
}

# 检查进程是否运行
is_process_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        fi
    fi
    
    # 检查是否有相关训练进程在运行
    if pgrep -f "swarm_launcher.py" > /dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

# 启动训练进程
start_training() {
    echo_blue "🚀 启动 Mac M4 优化版 RL Swarm 训练..."
    
    # 应用 Mac M4 优化环境变量
    export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
    export OMP_NUM_THREADS=8
    export MKL_NUM_THREADS=8
    export PYTORCH_ENABLE_MPS_FALLBACK=1
    export CPU_ONLY=1
    export HF_HUB_DOWNLOAD_TIMEOUT=300
    export HF_DATASETS_CACHE="$HOME/.cache/huggingface/datasets"
    export HF_MODELS_CACHE="$HOME/.cache/huggingface/transformers"
    
    # 设置 run_rl_swarm.sh 需要的环境变量
    export CONNECT_TO_TESTNET=true
    # export SWARM_CONTRACT="0xFaD7C5e93f28257429569B854151A1B8DCD404c2"
    export HUGGINGFACE_ACCESS_TOKEN="None"
    export HF_TOKEN=""  # 确保为空，这样会触发交互提示
    
    # 创建缓存目录
    mkdir -p "$HF_DATASETS_CACHE"
    mkdir -p "$HF_MODELS_CACHE"
    
    # 激活虚拟环境
    if [ -f ".venv/bin/activate" ]; then
        source .venv/bin/activate
    else
        echo_red "❌ 虚拟环境不存在，请先运行部署脚本"
        return 1
    fi
    
    # 使用自动输入启动训练
    echo_blue "📝 使用预设参数启动训练 (HuggingFace: $DEFAULT_HF_PUSH, 默认模型)"
    
    # 创建自动输入（基于最新的 run_rl_swarm.sh 交互流程）
    {
        echo "$DEFAULT_HF_PUSH"      # HuggingFace Hub 推送选择
        echo "$DEFAULT_MODEL_NAME"   # 模型名称（留空使用默认）
    } | ./run_rl_swarm.sh > "$LOG_FILE" 2>&1 &
    
    local pid=$!
    echo "$pid" > "$PID_FILE"
    echo_green "✅ 训练进程已启动，PID: $pid"
    
    # 等待一段时间检查进程是否成功启动
    sleep 15
    if ! ps -p "$pid" > /dev/null 2>&1; then
        echo_red "❌ 训练进程启动失败"
        rm -f "$PID_FILE"
        return 1
    fi
    
    return 0
}

# 信号处理
trap cleanup SIGINT SIGTERM

# 主监控循环
main() {
    local restart_count=0
    
    echo_green "🎯 Mac M4 RL Swarm 自动监控启动"
    echo_blue "📊 配置: Mac mini M4 16GB+256GB"
    echo_blue "📝 日志文件: $LOG_FILE"
    echo_blue "🔄 无限重启模式: 7*24小时持续运行"
    echo_blue "⏱️  检查间隔: ${CHECK_INTERVAL}秒"
    echo_blue "⏰ 重启延迟: ${RESTART_DELAY}秒"
    echo ""
    
    # 初始启动
    if ! start_training; then
        echo_red "❌ 初始启动失败"
        exit 1
    fi
    
    # 监控循环
    while true; do
        sleep "$CHECK_INTERVAL"
        
        if ! is_process_running; then
            echo_yellow "⚠️  检测到训练进程已结束"
            
            restart_count=$((restart_count + 1))
            echo_yellow "🔄 准备第 $restart_count 次重启 (无限重启模式)"
            echo_yellow "⏰ 等待 $RESTART_DELAY 秒后重启..."
            
            sleep "$RESTART_DELAY"
            
            if start_training; then
                echo_green "✅ 第 $restart_count 次重启成功"
            else
                echo_red "❌ 第 $restart_count 次重启失败，将继续尝试"
            fi
        fi
        # 移除了静默日志记录，不再向日志文件写入自定义监控信息
    done
    
    cleanup
}

# 检查是否在正确的目录
if [ ! -f "run_rl_swarm.sh" ]; then
    echo_red "❌ 错误: 请在 rl-swarm 项目根目录下运行此脚本"
    exit 1
fi

# 检查虚拟环境
if [ ! -d ".venv" ]; then
    echo_red "❌ 错误: 虚拟环境不存在，请先运行部署脚本创建环境"
    exit 1
fi

echo_blue "🎮 使用方法:"
echo_blue "   启动监控: ./auto_monitor_mac_m4.sh"
echo_blue "   停止监控: Ctrl+C"
echo_blue "   查看日志: tail -f $LOG_FILE"
echo ""

# 启动主程序
main

EOF

cd ~/Desktop/gensyn/rl-swarm && chmod +x auto.sh

cd ~/Desktop/gensyn/rl-swarm && sh auto.sh
