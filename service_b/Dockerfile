# 构建阶段
FROM golang:1.22-alpine AS builder
RUN apk add --no-cache gcc musl-dev

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# 编译 Service B
RUN go build -o risk_service ./service_b/main.go

# 运行阶段
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/risk_service .

CMD ["./risk_service"]