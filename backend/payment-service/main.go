package main

import (
	"log"
	"net"
	"net/http"
	"os"
	"payment-service/database"
	"payment-service/handlers"
	pb "payment-service/proto"

	"github.com/gin-gonic/gin"
	"github.com/soheilhy/cmux"
	"google.golang.org/grpc"
)

func main() {
	database.Connect()
	initNATS()

	// ---- HTTP server (Gin) ----
	r := gin.Default()

	r.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	cart := r.Group("/api/cart")
	{
		cart.GET("", handlers.GetCart)
		cart.POST("/items", handlers.AddToCart)
		cart.DELETE("/items/:tourId", handlers.RemoveFromCart)
		cart.POST("/checkout", handlers.Checkout)
	}

	r.GET("/api/purchases", handlers.GetPurchases)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8086"
	}

	lis, err := net.Listen("tcp", ":"+port)
	if err != nil {
		log.Fatalf("Failed to listen on port %s: %v", port, err)
	}

	m := cmux.New(lis)
	grpcL := m.MatchWithWriters(cmux.HTTP2MatchHeaderFieldSendSettings("content-type", "application/grpc"))
	httpL := m.Match(cmux.HTTP1Fast())

	grpcServer := grpc.NewServer()
	pb.RegisterPaymentServiceServer(grpcServer, &paymentGrpcServer{})

	go func() {
		if err := grpcServer.Serve(grpcL); err != nil {
			log.Printf("gRPC server stopped: %v", err)
		}
	}()

	go func() {
		if err := http.Serve(httpL, r); err != nil {
			log.Printf("HTTP server stopped: %v", err)
		}
	}()

	log.Printf("Listening on :%s (HTTP + gRPC multiplexed)", port)
	if err := m.Serve(); err != nil {
		log.Fatalf("cmux serve error: %v", err)
	}
}
