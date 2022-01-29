CREATE TABLE list (
  id serial PRIMARY KEY,
  name text NOT NULL UNIQUE
);

CREATE TABLE todo (
  id serial PRIMARY KEY,
  name text NOT NULL,
  list_id integer NOT NULL
    REFERENCES list(id) ON DELETE CASCADE,
  completed boolean NOT NULL DEFAULT false
);