-- +goose Up
-- SQL in this section is executed when the migration is applied.
alter table groups
add constraint one_of_parent check (
    (case when agency_id is null then 0 else 1 end) +
    (case when brand_id is null then 0 else 1 end) +
    (case when organization_id is null then 0 else 1 end) = 1
);


-- +goose Down
-- SQL in this section is executed when the migration is rolled back.
alter table groups drop constraint one_of_parent;