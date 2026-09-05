CREATE TABLE estimates (
  id bigint CONSTRAINT estimates_pk PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  site_id bigint NOT NULL CONSTRAINT estimates_site_id_fk 
