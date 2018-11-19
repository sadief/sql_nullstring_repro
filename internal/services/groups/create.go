package groups

import (
	"context"
	"fmt"

	api "github.com/Z2hMedia/sql_nullstring_repro/api"
)

func (s *service) Create(ctx context.Context, in *api.CreateGroupRequest) (*api.Group, error) {
	return nil, fmt.Errorf("Create group not implemented yet")
}
