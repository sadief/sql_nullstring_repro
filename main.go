package main

import (
	"context"
	"log"
	"math/rand"
	"time"

	"github.com/Z2hMedia/backend-go-library/app/gRPC"
	api "github.com/Z2hMedia/sql_nullstring_repro/api"
	"github.com/Z2hMedia/sql_nullstring_repro/internal"
	"github.com/Z2hMedia/users_service/lib/validation"
)

var (
	// Version is set by the build process, contains semantic version
	Version string
	// Build is set by the build process, contains sha tag of build
	Build string
	// Repo is set by the build process, contains the repo where the code for this binary was built from
	Repo string
)

func main() {
	// set the default timeout used by http gateway
	gRPC.DefaultTimeout = 4 * time.Second

	// initialize global pseudo random generator
	rand.Seed(time.Now().Unix())

	ctx := context.Background()
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	theApp, err := internal.Setup(ctx, Version, Build, Repo)
	if err != nil {
		log.Fatal(err)
	}
	defer theApp.Notifier.Monitor()

	vconf := validation.Config{
		Services: map[string]interface{}{
			"groups.Service": (*api.ServiceServer)(nil),
		},
	}
	validator, err := validation.New(vconf, theApp)
	if err != nil {
		log.Fatal(err)
	}
	theApp.AddUnaryInterceptor(validator.UnaryMiddleware)
	theApp.AddStreamInterceptor(validator.StreamMiddleware)

	err = groups.SetupService(ctx, theApp, Version, Build, Repo, validator)
	if err != nil {
		panic(err)
	}

	err = theApp.Start(ctx, cancel)
	if err != nil {
		log.Printf("Error starting or shutting down app: %v", err)
		return
	}

	log.Printf("Server shutdown complete")
}
