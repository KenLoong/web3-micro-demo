# ==============================================================================
# Makefile 增强版 - 支持单服务操作
# ------------------------------------------------------------------------------
# 使用说明 (Usage):
# 
# 1. 全局操作:
#    make up              - 启动所有服务 (构建并后台运行)
#    make down            - 停止并移除所有服务、网络
#    make logs            - 查看所有服务实时日志
#
# 2. 单服务操作 (通过 s 变量指定，可选值: service_a, service_b, nacos):
#    make check s=service_a    - 只检查服务 A 的代码语法
#    make build s=service_b    - 只重新构建服务 B 的镜像
#    make up s=service_b    - 只启动服务 B
#    make stop s=service_b     - 只停止服务 B
#    make restart s=service_a  - 只重启服务 A
#    make logs s=service_b     - 只看服务 B 的日志
#
# 3. 其他工具:
#    make scale n=3       - 扩容服务 B 到 3 个副本
#    make nacos           - 浏览器打开 Nacos 后台
# ==============================================================================

# 默认变量
s ?=                   # 默认服务名为空（代表全部）
n ?= 2                 # 默认扩容副本数为 2

.PHONY: help check build up start stop restart down logs ps scale nacos

# 默认帮助命令
help:
	@echo "可用命令示例:"
	@echo "  make check s=service_a    - 仅本地编译检查服务 A"
	@echo "  make up                   - 启动所有服务"
	@echo "  make up s=service_b       - 仅启动/更新服务 B"
	@echo "  make stop s=service_a     - 仅停止服务 A"
	@echo "  make restart s=service_b  - 仅重启服务 B"
	@echo "  make logs s=service_a     - 仅查看服务 A 日志"
	@echo "  make down                 - 停止并清理整个内网"

# 1. 代码编译检查 (本地执行)
check:
	@if [ "$(s)" = "" ]; then \
		echo ">>> 正在检查所有服务代码..."; \
		go build -o /dev/null ./service_a/main.go && echo ">>> Service A [OK]"; \
		go build -o /dev/null ./service_b/main.go && echo ">>> Service B [OK]"; \
	else \
		echo ">>> 正在检查 $(s) 代码..."; \
		go build -o /dev/null ./$(s)/main.go && echo ">>> $(s) [OK]"; \
	fi

# 2. 编译镜像 (不运行)
build:
	@echo ">>> 正在构建镜像 $(s)..."
	docker-compose build $(s)

# 3. 启动服务 (后台运行)
up:
	@echo ">>> 正在启动服务 $(s)..."
	docker-compose up -d --build $(s)

# 4. 停止特定服务容器 (不移除网络)
stop:
	@echo ">>> 正在停止服务 $(s)..."
	docker-compose stop $(s)

# 5. 单独重启特定服务
# 原理: 先停止容器，再重新启动
restart:
	@if [ "$(s)" = "" ]; then \
		echo ">>> 正在重启所有服务..."; \
		docker-compose restart; \
	else \
		echo ">>> 正在重启服务 $(s)..."; \
		docker-compose restart $(s); \
	fi

# 6. 停用并清理整个环境 (慎用)
down:
	@echo ">>> 正在停止并清理整个内网环境..."
	docker-compose down

# 7. 查看日志
logs:
	@echo ">>> 正在查看 $(s) 日志 (Ctrl+C 退出)..."
	docker-compose logs -f $(s)

# 8. 查看状态
ps:
	docker-compose ps

# 9. 水平扩容 Service B
scale:
	@echo ">>> 正在将 Service B 扩容到 $(n) 个实例..."
	docker-compose up -d --scale service_b=$(n)

# 10. 浏览器打开 Nacos
nacos:
	@open http://localhost:8848/nacos