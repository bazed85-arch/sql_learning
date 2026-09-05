CREATE TABLE estimates (
  id bigint CONSTRAINT estimates_pk PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  site_id bigint NOT NULL CONSTRAINT estimates_site_id_fk REFERENCES sites (id) ON DELETE RESTRICT,
  number text NOT NULL CONSTRAINT estimates_number_uq UNIQUE, 
  status text NOT NULL CONSTRAINT estimates_status_chk CHECK (status IN ('draft','sent','approved','rejected')),
  estimate_date date NOT NULL,
  valid_until date,
  currency text NOT NULL DEFAULT ('EUR'),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
  );

CREATE TABLE deliveries (
  id bigint CONSTRAINT deliveries_pk PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  supplier_id bigint NOT NULL CONSTRAINT deliveries_supplier_id_fk REFERENCES suppliers (id) ON DELETE RESTRICT,
  delivery_note_number text NOT NULL,
  delivery_date date NOT NULL,
  status text NOT NULL CONSTRAINT deliveries_status_chk CHECK (status IN ('draft','received','received_with_issues','rejected')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT deliveries_supplier_id_delivery_note_number_uq UNIQUE (supplier_id, delivery_note_number)
  );


