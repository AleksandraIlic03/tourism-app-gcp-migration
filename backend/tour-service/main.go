package main

import (
	"context"
	"log"
	"net"
	"net/http"
	"os"
	"tour-service/database"
	"tour-service/handlers"
	"tour-service/proto"
	"tour-service/tracing"

	"github.com/gin-gonic/gin"
	"github.com/soheilhy/cmux"
	"go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
	"go.opentelemetry.io/otel"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

func main() {
	database.Connect()

	shutdown := tracing.InitTracer("tour-service")
	defer func() {
		if err := shutdown(context.Background()); err != nil {
			log.Printf("Error shutting down tracer: %v", err)
		}
	}()

	tracer := otel.Tracer("tour-service")

	go StartNATSSubscriber()

	r := gin.Default()

	r.Use(otelgin.Middleware("tour-service"))

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

	api := r.Group("/api/tours")
	{
		api.POST("", handlers.CreateTour)
		api.GET("/my", handlers.GetMyTours)
		api.GET("/published", handlers.GetPublishedTours)
		api.GET("/:id", handlers.GetTourByIdNew)

		api.PUT("/:id/publish", handlers.PublishTour)
		api.PUT("/:id/archive", handlers.ArchiveTour)
		api.PUT("/:id/reactivate", handlers.ReactivateTour)
		api.PATCH("/:id/price", handlers.UpdatePrice)
		api.POST("/:id/transport-times", handlers.AddTransportTime)

		api.POST("/:id/keypoints", handlers.CreateKeypoint)
		api.GET("/:id/keypoints", handlers.GetKeypoints)
		api.PUT("/:id/keypoints/:kpId", handlers.UpdateKeypoint)
		api.DELETE("/:id/keypoints/:kpId", handlers.DeleteKeypoint)

		api.POST("/:id/reviews", handlers.CreateReview)
		api.GET("/:id/reviews", handlers.GetReviews)

		api.POST("/:id/executions", handlers.StartExecution)
	}

	executions := r.Group("/api/executions")
	{
		executions.GET("/my", handlers.GetMyExecutions)
		executions.GET("/:execId", handlers.GetExecutionById)
		executions.PUT("/:execId/position", handlers.UpdatePosition)
		executions.PUT("/:execId/abandon", handlers.AbandonExecution)
	}

	internal := r.Group("/internal")
	{
		internal.POST("/record-purchase", handlers.RecordPurchase)
		internal.GET("/check-purchase", handlers.CheckPurchase)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8083"
	}

	lis, err := net.Listen("tcp", ":"+port)
	if err != nil {
		log.Fatalf("Failed to listen on port %s: %v", port, err)
	}

	m := cmux.New(lis)
	grpcL := m.MatchWithWriters(cmux.HTTP2MatchHeaderFieldSendSettings("content-type", "application/grpc"))
	httpL := m.Match(cmux.HTTP1Fast())

	grpcServer := grpc.NewServer(
		grpc.UnaryInterceptor(otelGrpcUnaryInterceptor(tracer)),
	)
	reflection.Register(grpcServer)
	proto.RegisterTourServiceServer(grpcServer, &TourGrpcServer{})

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
