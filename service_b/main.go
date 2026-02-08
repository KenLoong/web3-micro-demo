package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"os"
	"time"

	"web3-micro-demo/pb"

	"github.com/nacos-group/nacos-sdk-go/v2/clients"
	"github.com/nacos-group/nacos-sdk-go/v2/clients/naming_client"
	"github.com/nacos-group/nacos-sdk-go/v2/common/constant"
	"github.com/nacos-group/nacos-sdk-go/v2/vo"
	"google.golang.org/grpc"
)

// 1. 定义 gRPC 服务实现
type riskServer struct {
	pb.UnimplementedRiskServiceServer
}

func (s *riskServer) CheckAddress(ctx context.Context, in *pb.RiskRequest) (*pb.RiskResponse, error) {
	fmt.Printf("【服务B】收到风控校验请求: %s\n", in.Address)
	isSafe := true
	// 简单模拟：0x0 开头的地址设为不安全
	if in.Address == "0x0" {
		isSafe = false
	}
	return &pb.RiskResponse{IsSafe: isSafe}, nil
}

// 2. 封装：带重试机制的 Nacos 注册函数
func registerWithRetry(client naming_client.INamingClient, param vo.RegisterInstanceParam, maxRetries int) error {
	for i := 1; i <= maxRetries; i++ {
		success, err := client.RegisterInstance(param)
		if err == nil && success {
			fmt.Printf("【服务B】第 %d 次尝试：注册成功！\n", i)
			return nil
		}

		fmt.Printf("【服务B】第 %d 次尝试：Nacos 尚未就绪 (%v)，5秒后重试...\n", i, err)
		time.Sleep(5 * time.Second)
	}
	return fmt.Errorf("超过最大重试次数 %d，注册失败", maxRetries)
}

func main() {
	// --- A. 准备 gRPC 环境 ---
	// 监听本地 8081 端口
	lis, err := net.Listen("tcp", ":8081")
	if err != nil {
		log.Fatalf("监听端口失败: %v", err)
	}
	grpcServer := grpc.NewServer()
	pb.RegisterRiskServiceServer(grpcServer, &riskServer{})

	// --- B. 准备 Nacos 客户端 ---
	// 服务端配置：指向 Docker 内网中的 nacos 容器
	serverConfigs := []constant.ServerConfig{
		{
			IpAddr: "nacos",
			Port:   8848,
		},
	}

	// 客户端配置
	clientConfig := constant.ClientConfig{
		NamespaceId:         "public", // 如果有命名空间需求请修改
		TimeoutMs:           5000,
		NotLoadCacheAtStart: true,
		LogDir:              "/tmp/nacos/log",
		CacheDir:            "/tmp/nacos/cache",
		Username:            "nacos", // Nacos 2.x 默认账号
		Password:            "nacos", // Nacos 2.x 默认密码
	}

	// 创建服务发现客户端
	namingClient, err := clients.NewNamingClient(vo.NacosClientParam{
		ClientConfig:  &clientConfig,
		ServerConfigs: serverConfigs,
	})
	if err != nil {
		log.Fatalf("创建 Nacos 客户端失败: %v", err)
	}

	hostName, _ := os.Hostname()
	fmt.Printf("当前容器主机名: %s\n", hostName)

	// --- C. 执行注册 (带重试) ---
	registerParam := vo.RegisterInstanceParam{
		Ip:          hostName,       // 使用容器主机名作为 IP
		Port:        8081,           // gRPC 服务端口
		ServiceName: "risk-service", // 注册到 Nacos 的服务名
		Weight:      10,
		Enable:      true,
		Healthy:     true,
	}

	// 尝试注册，最多重试 12 次 (共计 1 分钟)
	err = registerWithRetry(namingClient, registerParam, 12)
	if err != nil {
		log.Fatal(err)
	}

	// --- D. 启动 gRPC 服务 ---
	fmt.Println("【服务B】gRPC 服务已启动在 :8081...")
	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("启动 gRPC 服务失败: %v", err)
	}
}
