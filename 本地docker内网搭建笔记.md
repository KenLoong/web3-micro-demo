
既然你是第一次动手搭建“内网”和“服务发现”，我们不需要云服务器。你的 MacBook Air 性能完全足够（甚至更方便调试）。
我们将使用 Docker Desktop for Mac。它会在你的 Mac 内部虚拟出一个 Linux 环境，并建立一个虚拟内网。每个微服务都会跑在独立的 Docker 容器里。
这是最详尽的实战手册，分为 7 个步骤。

--------------------------------------------------------------------------------

准备工作：安装必备工具
1.Docker Desktop: 去官网下载并安装。启动后，确保右上角的小鲸鱼图标是运行状态。
2.Go 环境: 你的 Mac 应该已经装了。
3.Protobuf 编译器: 执行 brew install protobuf，然后安装 Go 插件：
- go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
- go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
- 检查是否安装成功：
```sh
protoc --version
protoc-gen-go --version
protoc-gen-go-grpc --version
```

--------------------------------------------------------------------------------
第一步：建立项目结构
在你的 Mac 桌面或某个目录下，建立以下结构：
mkdir web3-micro-demo && cd web3-micro-demo
go mod init web3-micro-demo

# 创建目录
```sh
mkdir -p pb            # 存放协议文件
mkdir -p service_a     # 钱包服务
mkdir -p service_b     # 风控服务
```
--------------------------------------------------------------------------------
第二步：定义“共同语言” (Protobuf)
服务 A 怎么调用服务 B？得先定协议。
创建 pb/risk.proto：
```proto
syntax = "proto3";
package pb;
option go_package = "./pb";

service RiskService {
  rpc CheckAddress (RiskRequest) returns (RiskResponse);
}

message RiskRequest {
  string address = 1;
}

message RiskResponse {
  bool is_safe = 1;
}
```


执行编译命令：
在项目根目录运行：
```sh
protoc --go_out=. --go-grpc_out=. pb/risk.proto
```
你会发现 pb 目录下多了两个 .go 文件。 (生成了risk.pb.go和risk_grpc.pb.go)
--------------------------------------------------------------------------------
第三步：搭建内网核心 (Nacos)
我们要让 Nacos 先跑起来，它是所有服务的“电话簿”。
在根目录创建 docker-compose.yml：
```yaml
services:
  nacos:
    # 经过验证，这个版本在 Mac M 芯片上支持最好
    image: nacos/nacos-server:v2.3.1-slim
    container_name: nacos
    environment:
      - MODE=standalone
      - PREFER_HOST_MODE=hostname
      # --- 以下三项是 Nacos v2.2.1+ 必须设置的，否则无法启动 ---
      - NACOS_AUTH_ENABLE=true
      - NACOS_AUTH_TOKEN=SecretKey012345678901234567890123456789012345678901234567890123456789
      - NACOS_AUTH_IDENTITY_KEY=nacos
      - NACOS_AUTH_IDENTITY_VALUE=nacos
    ports:
      - "8848:8848"
      - "9848:9848"
      - "9849:9849"
    networks:
      - micro-net

networks:
  micro-net:
    driver: bridge
```

启动命令： docker-compose up -d nacos
打开浏览器访问 http://localhost:8848/nacos（账号密码 nacos/nacos），能进去说明内网中心好了。

--------------------------------------------------------------------------------

第四步：开发服务 B (风控 - 响应者)
它是被调用者。它启动后要做两件事：
1.启动 gRPC 监听。
2.去 Nacos 登记自己的名字和 IP。
创建 service_b/main.go： (具体内容看代码)

--------------------------------------------------------------------------------

第五步：开发服务 A (钱包 - 发起者)

它是调用者。它不知道服务 B 的 IP，所以它要问 Nacos。
创建 service_a/main.go： (具体内容看代码)

--------------------------------------------------------------------------------

第六步：全家桶启动 (内网合体)
修改你的 docker-compose.yml，把 A 和 B 加入内网：(完整代码看docker-compose.yml)

第七步：一键启动

在终端执行：
```sh
docker-compose up --build
```

你会看到：
1.Nacos 先启动。
2.Service B 启动并向 Nacos 注册。
3.Service A 启动，问 Nacos 要到了 service_b:8081 这个地址。
4.Service A 打印出：调用成功！风控结果: true。

--------------------------------------------------------------------------------

为什么这叫“内网”和“服务发现”？
- 内网：Service A 和 Service B 并没有暴露端口到你的 Mac（除非你写 ports）。它们在 Docker 创造的 micro-net 里私聊。
- 服务发现：你有没有发现 Service A 的代码里一行 IP 地址都没写？它只知道对方叫 risk-service。哪怕你以后启动 10 个 Service B，Nacos 也会自动把负载均衡后的 IP 告诉 A。
这就完成了从后端开发到初级 DevOps 架构的跨越！如果你在这个过程中遇到报错（比如 Mac M1 芯片的镜像问题），请告诉我。
