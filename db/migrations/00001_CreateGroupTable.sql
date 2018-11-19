-- +goose Up
-- SQL in this section is executed when the migration is applied.
create table groups {
    id uuid primary key default (gen_random_uuid()),
    name text not null,
    first_id uuid,
    second_id uuid,
    thrd_id uuid,
    created_at timestamptz not null default (now()),
    updated_at timestamptz not null default (now())
};


-- +goose Down
-- SQL in this section is executed when the migration is rolled back.
drop table groups;
