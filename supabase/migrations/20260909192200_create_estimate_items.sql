CREATE TABLE estimate_items (
  id bigint CONSTRAINT estimate_items_pk PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  estimate_id	bigint NOT NULL CONSTRAINT estimate_items_estimate_id_fk REFERENCES estimates (id) ON DELETE CASCADE,
  material_id bigint NOT NULL CONSTRAINT estimate_items_material_id_fk REFERENCES materials (id) ON DELETE RESTRICT,
  line_no int NOT NULL CONSTRAINT estimate_items_line_no_chk CHECK (line_no > 0),
  description text,
  unit_id bigint NOT NULL CONSTRAINT estimate_items_unit_id_fk REFERENCES units (id) ON DELETE RESTRICT,
  quantity numeric(14,3) NOT NULL CONSTRAINT estimate_items_quantity_chk CHECK (quantity > 0),
  unit_price numeric(14,2) NOT NULL CONSTRAINT estimate_items_unit_price_chk CHECK (unit_price >= 0),
  total numeric(14,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT estimate_items_estimate_id_line_no_uq UNIQUE (estimate_id, line_no)
 );
