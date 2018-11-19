package groups

import (
	"context"

	"github.com/Z2hMedia/backend-go-library/app"
	"github.com/Z2hMedia/backend-go-library/app/gRPC"
	"github.com/Z2hMedia/backend-go-library/interfaces"
	api "github.com/Z2hMedia/ownership_service/api"
)

// Service ...
type Service struct {
	db      interfaces.IStore
	notify  interfaces.ErrorNotifier
	version string
	build   string
	repo    string
}

// SetupService sets up the users service so that it can start
// serving the incoming GRPC requests
// SetupService ...
func SetupService(_ context.Context, ba *app.BaseApp, version, build, repo string) error {
	db, err := ba.Database("default")
	if err != nil {
		return err
	}

	srv := &Service{
		db:      db,
		notify:  ba.Notifier,
		version: version,
		build:   build,
		repo:    repo,
	}

	ba.RegisterHandler(func(s *gRPC.Server) error {
		api.RegisterGroupsServiceServer(s.Srv, srv)
		return nil
	})

	//ba.RegisterGateway(api.RegisterOrdersServiceHandler)

	return nil
}
