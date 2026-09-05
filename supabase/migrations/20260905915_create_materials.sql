CREATE TABLE materials (
  id bigint CONSTRAINT materials_pk PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  article_no text CONSTRAINT materials_article_no_uq UNIQUE,
  name text NOT NULL,
  description text,
  unit_id bigint NOT NULL CONSTRAINT materials_unit_id_fk REFERENCES units (id) ON DELETE RESTRICT,
  category text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
  );
