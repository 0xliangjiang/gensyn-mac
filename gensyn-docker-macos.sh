#!/bin/bash
set -euo pipefail

log_file="./deploy_rl_swarm_0.5.log"

info() {
    echo -e "[INFO] $*" | tee -a "$log_file"
}

error() {
    echo -e "[ERROR] $*" >&2 | tee -a "$log_file"
    exit 1
}

echo "[1/15] 🧹 检查 Homebrew..." | tee -a "$log_file"

if ! command -v brew &> /dev/null; then
    info "Homebrew 未安装，正在安装..."
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
    info "Homebrew 已安装，版本：$(brew --version | head -n 1)"
fi

echo "[3/15] 🐳 检查 Docker..." | tee -a "$log_file"
if ! command -v docker &> /dev/null; then
    info "Docker 未安装，正在通过 Homebrew 安装 Docker Desktop..."
    if ! brew install --cask docker; then
        error "Docker Desktop 安装失败，请手动从 https://www.docker.com/products/docker-desktop/ 安装。"
    fi
    echo "🚀 Docker 安装成功！自动启动 Docker Desktop..."
    open -a "Docker"
    info "请等待 Docker Desktop 启动完成后再继续（可能需要几分钟）..."
    read -p "按 Enter 继续（确保 Docker Desktop 已运行）..."
else
    info "Docker 已安装，版本：$(docker --version)"
fi

echo "[4/15] ⚙️ 检查 Docker Compose..." | tee -a "$log_file"
if ! command -v docker-compose &> /dev/null; then
    info "安装 Docker Compose..."
    if ! brew install docker-compose; then
        error "Docker Compose 安装失败。"
    fi
else
    info "Docker Compose 已安装，版本：$(docker-compose --version)"
fi

# 检查 rl-swarm-0.5 目录是否存在
if [ ! -d "rl-swarm-0.5" ]; then
    info "正在克隆 Gensyn RL Swarm 仓库..."
    if ! git clone https://github.com/readyName/rl-swarm-0.5.git; then
        error "克隆失败，请检查网络或 Git 配置。"
    fi
    cd rl-swarm-0.5 && cat << 'EOF' > "docker-compose.yaml"
services:
  fastapi:
    image: registry.cn-hangzhou.aliyuncs.com/liangjiang-tools/gensyn:base-0.0.1
    environment:
      - OTEL_SERVICE_NAME=rlswarm-fastapi
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
    depends_on:
      - otel-collector
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/api/healthz"]
      interval: 30s
      retries: 3

  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.120.0
    ports:
      - "4317:4317"  # OTLP gRPC
      - "4318:4318"  # OTLP HTTP
      - "55679:55679"  # Prometheus metrics (optional)
    environment:
      - OTEL_LOG_LEVEL=DEBUG
    healthcheck:
      test: ["CMD", "grpc_health_probe", "-addr=localhost:4317"]
      interval: 5s
      retries: 5

  swarm-cpu:
    profiles: ["swarm"]
    build:
      context: .
      dockerfile: containerfiles/swarm-node/swarm.containerfile
      args:
        - BASE_IMAGE=ubuntu:24.04
    ports:
      - 3000:3000
    volumes:
      - ./user/modal-login:/home/gensyn/rl_swarm/modal-login/temp-data
      - ./user/keys:/home/gensyn/rl_swarm/keys
      - ./user/configs:/home/gensyn/rl_swarm/configs
      - ./user/logs:/home/gensyn/rl_swarm/logs
    environment:
      - HF_TOKEN=${HF_TOKEN}
      - GENSYN_RESET_CONFIG=${GENSYN_RESET_CONFIG}
    restart: always

  # Requires the NVIDIA Drivers version >=525.60.13 to be installed, as well
  # as the nvidia-container-toolkit.
  # https://docs.nvidia.com/deploy/cuda-compatibility/index.html#cuda-11-and-later-defaults-to-minor-version-compatibility
  # https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/
  # https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
  swarm-gpu:
    profiles: ["swarm"]
    build:
      context: .
      dockerfile: containerfiles/swarm-node/swarm.containerfile
      args:
        - BASE_IMAGE=nvidia/cuda:12.6.3-cudnn-devel-ubuntu24.04
    ports:
      - 3000:3000
    volumes:
      - ./user/modal-login:/home/gensyn/rl_swarm/modal-login/temp-data
      - ./user/keys:/home/gensyn/rl_swarm/keys
      - ./user/configs:/home/gensyn/rl_swarm/configs
      - ./user/logs:/home/gensyn/rl_swarm/logs
    environment:
      - HF_TOKEN=${HF_TOKEN}
      - GENSYN_RESET_CONFIG=${GENSYN_RESET_CONFIG}
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    restart: always
    EOF
    
else
    info "仓库已存在。"
    echo -n "是否覆盖现有 rl-swarm-0.5 目录？（y/N）："
    read -r overwrite
    case $overwrite in
        [Yy]*)
            info "删除现有 rl-swarm-0.5 目录..."
            rm -rf rl-swarm-0.5 || error "删除 rl-swarm-0.5 目录失败"
            info "正在克隆 Gensyn RL Swarm 仓库..."
            if ! git clone https://github.com/readyName/rl-swarm-0.5.git; then
                error "克隆失败，请检查网络或 Git 配置。"
            fi
            ;;
        *)
            info "保留现有 rl-swarm-0.5 目录，跳过克隆。"
            ;;
    esac
fi

cd rl-swarm-0.5 || error "进入 rl-swarm-0.5 目录失败"

info "🚀 准备运行 swarm-cpu 容器..."

MAX_RETRIES=100
ATTEMPT=1

while [ $ATTEMPT -le $MAX_RETRIES ]; do
    info "尝试第 $ATTEMPT 次构建并运行 swarm-cpu..."

    # 检查端口 3000 是否占用
    PORT_PID=$(lsof -i :3000 -t || true)
    if [ -n "$PORT_PID" ]; then
        info "⚠️ 端口 3000 被进程 $PORT_PID 占用，尝试释放..."
        kill -9 "$PORT_PID" && info "✅ 已成功释放端口 3000"
    else
        info "✅ 端口 3000 空闲"
    fi

    if docker-compose run --rm --build -Pit swarm-cpu; then
        info "✅ 容器运行成功！"
        break
    else
        info "⚠️ 第 $ATTEMPT 次失败，等待 3 秒后重试..."
        ((ATTEMPT++))
        sleep 3
    fi
done

if [ $ATTEMPT -gt $MAX_RETRIES ]; then
    error "❌ 多次尝试仍无法成功构建/运行容器，请检查 Dockerfile、网络连接或 compose 配置。"
fi
