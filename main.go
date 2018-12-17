package main

import (
	"database/sql"

	"github.com/davecgh/go-spew/spew"
	"github.com/gofrs/uuid/v3"
	"github.com/jmoiron/sqlx"
)

func main() {
	query := `update things
set parent_id=:pid, name=:name
where value in (:values)`

	id, _ := uuid.FromString("de222731-5fcf-406f-99d4-00e081866065")
	pid, _ := uuid.FromString("e3b66e1e-41f1-49a6-b2c9-8a4f00c58860")

	v := struct {
		ID       *uuid.UUID     `db:"id"`
		ParentId *uuid.UUID     `db:"pid"`
		Name     sql.NullString `db:"name"`
		Values   []string       `db:"values"`
	}{
		ID:       &id,
		ParentId: &pid,
		Name:     sql.NullString{Valid: false},
		Values:   []string{"one", "two", "three"},
	}

	query, args, err := sqlx.Named(query, v)
	spew.Dump(query, args, err)

	query, args, err = sqlx.In(query, args...)
	spew.Dump(query, args, err)
}
