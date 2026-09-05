CREATE TABLE estimates (
  id bigint CONSTRAINT estimates_pk PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  site_id bigint NOT NULL CONSTRAINT estimates_site_id_fk REFERENCES sites (id) ON DELETE RESTRICT,
  number text NOT NULL CONSTRAINT estimates_number_uq UNIQUE, 
  status text NOT NULL CHECK 
