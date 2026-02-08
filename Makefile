# ==============================================================================
# Makefile 使用说明 (Usage):
# ------------------------------------------------------------------------------
# 1. 快速检查代码: 运行 `make check`。如果你改了代码但不确定是否写错，先用这个。
# 2. 首次启动:     运行 `make up`。它会自动下载镜像、编译代码并启动。
# 3. 查看日志:     运行 `make logs`。实时观察 A 和 B 服务的交互情况。
# 4. 水平扩容:     运行 `make scale n=3`。将 Service B (风控) 扩展到 3 个副本。
# 5. 彻底重来:     运行 `make restart`。当你想清理所有缓存重新开始时使用。
# 6. 进入 Nacos:   运行 `make nacos`。在 Mac 浏览器里一键打开管理页面。
# ==============================================================================

# 默认参数
n ?= 2

.PHONY: help check up down restart logs ps scale nacos

# 默认执行 help
help:
	@echo "可用命令:"
	@echo "  make check     - ⚡️ [最快] 仅本地编译代码，检测语法错误"
	@echo "  make up        - 🚀 构建镜像并在后台启动所有服务"
	@echo "  make down      - 🛑 停止并移除所有服务"
	@echo "  make restart   - 🔄 彻底停止并重新构建启动"
	@echo "  make logs      - 📝 实时跟踪查看所有服务的日志"
	@echo "  make ps        - 🔍 查看容器运行状态"
	@echo "  make scale n=3 - 📈 扩容 Service B (n 为目标副本数)"
	@echo "  make nacos     - 🌐 在浏览器打开 Nacos 后台"

# 1. 快速编译检查 (检查代码是否有错，不涉及 Docker)
check:
	@echo ">>> 正在检查代码编译状态..."
	@go build -o /dev/null ./service_a/main.go && echo ">>> Service A [OK]"
	@go build -o /dev/null ./service_b/main.go && echo ">>> Service B [OK]"
	@echo ">>> ✅ 代码语法检测通过，可以放心部署。"

# 2. 启动服务 (后台运行)
up:
	@echo ">>> 正在构建并启动服务..."
	docker-compose up -d --build

# 3. 停止服务
down:
	@echo ">>> 正在停止并清理容器..."
	docker-compose down

# 4. 彻底重启
restart:
	@echo ">>> 正在执行彻底重置..."
	docker-compose down
	docker-compose up -d --build

# 5. 查看实时日志
logs:
	@echo ">>> 正在实时追踪日志 (Ctrl+C 退出)..."
	docker-compose logs -f

# 6. 查看容器状态
ps:
	docker-compose ps

# 7. 水平扩容
scale:
	@echo ">>> 正在将 Service B 扩容到 $(n) 个实例..."
	docker-compose up -d --scale service_b=$(n)

# 8. 快速打开 Nacos 管理界面 (Mac 专用)
nacos:
	@echo ">>> 正在打开 Nacos 控制台..."
	@open http://localhost:8848/nacos