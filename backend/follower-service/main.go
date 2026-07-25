package main

import (
	"context"
	"follower-service/database"
	"follower-service/handler"
	"follower-service/proto"
	"follower-service/repository"
	"follower-service/tracing"
	"log"
	"net"
	"net/http"
	"os"

	"github.com/gorilla/mux"
	"github.com/rs/cors"
	"github.com/soheilhy/cmux"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"google.golang.org/grpc"
)

func main() {
	database.Connect()
	defer database.Driver.Close(nil)

	shutdown := tracing.InitTracer("follower-service")
	defer func() {
		if err := shutdown(context.Background()); err != nil {
			log.Printf("Error shutting down tracer: %v", err)
		}
	}()

	tracer := otel.Tracer("follower-service")

	repo := repository.NewFollowerRepository(database.Driver)

	h := handler.NewFollowerHandler(repo)

	router := mux.NewRouter()

	router.Handle("/follow",
		otelhttp.NewHandler(http.HandlerFunc(h.Follow), "POST /follow"),
	).Methods("POST", "OPTIONS")

	router.Handle("/unfollow",
		otelhttp.NewHandler(http.HandlerFunc(h.Unfollow), "DELETE /unfollow"),
	).Methods("DELETE", "OPTIONS")

	router.Handle("/is-following/{followerId}/{followedId}",
		otelhttp.NewHandler(http.HandlerFunc(h.IsFollowing), "GET /is-following"),
	).Methods("GET", "OPTIONS")

	router.Handle("/following/{userId}",
		otelhttp.NewHandler(http.HandlerFunc(h.GetFollowing), "GET /following"),
	).Methods("GET", "OPTIONS")

	router.Handle("/recommendations/{userId}",
		otelhttp.NewHandler(http.HandlerFunc(h.GetRecommendations), "GET /recommendations"),
	).Methods("GET", "OPTIONS")

	c := cors.New(cors.Options{
		AllowedOrigins:   []string{"http://localhost:3000"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Content-Type", "Authorization"},
		AllowCredentials: true,
	})

	corsHandler := c.Handler(router)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8084"
	}

	lis, err := net.Listen("tcp", ":"+port)
	if err != nil {
		log.Fatalf("Failed to listen on port %s: %v", port, err)
	}

	m := cmux.New(lis)
	grpcL := m.MatchWithWriters(cmux.HTTP2MatchHeaderFieldSendSettings("content-type", "application/grpc"))
	httpL := m.Match(cmux.HTTP1Fast())

	grpcServer := grpc.NewServer(
		grpc.UnaryInterceptor(otelGrpcUnaryInterceptorFollower(tracer)),
	)
	proto.RegisterFollowerServiceServer(grpcServer, NewFollowerGrpcServer(repo))

	go func() {
		if err := grpcServer.Serve(grpcL); err != nil {
			log.Printf("gRPC server stopped: %v", err)
		}
	}()

	go func() {
		if err := http.Serve(httpL, corsHandler); err != nil {
			log.Printf("HTTP server stopped: %v", err)
		}
	}()

	log.Printf("Listening on :%s (HTTP + gRPC multiplexed)", port)
	if err := m.Serve(); err != nil {
		log.Fatalf("cmux serve error: %v", err)
	}
}
