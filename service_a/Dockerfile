# 构建阶段
FROM golang:1.22-alpine AS builder

# 安装构建依赖（有些 Go 库需要 gcc）
RUN apk add --no-cache gcc musl-dev

WORKDIR /app

# 先拷贝依赖文件，利用 Docker 缓存
COPY go.mod go.sum ./
RUN go mod download

# 拷贝全量代码（因为需要根目录的 pb 文件夹）
COPY . .

# 编译 Service A
RUN go build -o wallet_service ./service_a/main.go

# 运行阶段（使用更小的镜像）
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/wallet_service .

# 启动命令
CMD ["./wallet_service"]