CREATE TABLE supplier_materials (
  supplier_id bigint NOT NULL CONSTRAINT supplier_materials_supplier_id_fk REFERENCES suppliers (id) ON DELETE RESTRICT,
  material_id bigint NOT NULL CONSTRAINT supplier_materials_material_id_fk REFERENCES materials (id) ON DELETE RESTRICT,
  supplier_article_no text,
  price numeric(14,2) NOT NULL CONSTRAINT supplier_materials_price_chk CHECK (price >= 0),
  currency text NOT NULL DEFAULT 'EUR',
  min_order_quantity numeric(14,3) CONSTRAINT supplier_materials_min_order_quantity_chk CHECK (min_order_quantity > 0),
  lead_time_days int CONSTRAINT supplier_materials_lead_time_days_chk CHECK (lead_time_days >= 0),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT supplier_materials_pk PRIMARY KEY (supplier_id, material_id)
  );
