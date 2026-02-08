package main

import (
	"context"
	"fmt"
	"time"
	"web3-micro-demo/pb"

	"github.com/nacos-group/nacos-sdk-go/v2/clients"
	"github.com/nacos-group/nacos-sdk-go/v2/common/constant"
	"github.com/nacos-group/nacos-sdk-go/v2/vo"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func main() {
	// 1. 初始化 Nacos 客户端 (配置同上)
	sc := []constant.ServerConfig{{IpAddr: "nacos", Port: 8848}}
	cc := constant.ClientConfig{
		NamespaceId:         "public",
		TimeoutMs:           5000,
		NotLoadCacheAtStart: true,
		LogDir:              "/tmp/nacos/log",
		CacheDir:            "/tmp/nacos/cache",
		// 添加以下两行
		Username: "nacos",
		Password: "nacos",
	}
	namingClient, _ := clients.NewNamingClient(vo.NacosClientParam{
		ClientConfig:  &cc,
		ServerConfigs: sc,
	})

	fmt.Println("【服务A】启动，准备监听并调用服务B...")

	for {
		// 2. 服务发现：向 Nacos 要一个健康的实例
		instance, err := namingClient.SelectOneHealthyInstance(vo.SelectOneHealthInstanceParam{
			ServiceName: "risk-service",
		})

		if err != nil {
			fmt.Println("【服务A】暂未发现可用的风险检查服务，重试中...")
			time.Sleep(3 * time.Second)
			continue
		}

		// 3. 拨号并调用
		addr := fmt.Sprintf("%s:%d", instance.Ip, instance.Port)
		conn, err := grpc.Dial(addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
		if err != nil {
			fmt.Printf("连接失败: %v\n", err)
			continue
		}

		client := pb.NewRiskServiceClient(conn)
		resp, err := client.CheckAddress(context.Background(), &pb.RiskRequest{Address: "0x123456"})

		if err == nil {
			fmt.Printf("【服务A】成功调用服务B！地址安全状态: %v\n", resp.IsSafe)
		}

		conn.Close()
		time.Sleep(5 * time.Second) // 每5秒调用一次
	}
}
