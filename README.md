# gensyn-mac
gensyn mac一键启动脚本

### 安装brew

[https://brew.sh/](https://brew.sh/)

### 安装wget

brew install wget

### 一键执行脚本

```shell
wget -O gensyn-mac.sh https://raw.githubusercontent.com/0xliangjiang/gensyn-mac/refs/heads/main/gensyn-mac.sh && chmod +x gensyn-mac.sh && sh gensyn-mac.sh
```


### 一键执行更新脚本

```shell
wget -O gensyn-mac-update.sh https://raw.githubusercontent.com/0xliangjiang/gensyn-mac/refs/heads/main/gensyn-mac-update.sh && chmod +x gensyn-mac-update.sh && sh gensyn-mac-update.sh
```

### 一键执行docker脚本

```shell
wget -O gensyn-docker-macos.sh https://raw.githubusercontent.com/0xliangjiang/gensyn-mac/refs/heads/main/gensyn-docker-macos.sh && chmod +x gensyn-docker-macos.sh && sh gensyn-docker-macos.sh
```


### 网络超时
```shell
sed -i '' 's/startup_timeout: float = 15,/startup_timeout: float = 60,/' ~/Desktop/gensyn/rl-swarm/.venv/lib/python3.11/site-packages/hivemind/p2p/p2p_daemon.py
```


