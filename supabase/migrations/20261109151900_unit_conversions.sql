CREATE TABLE unit_conversions (
  from_unit_id bigint NOT NULL CONSTRAINT unit_conversions_from_unit_id_fk REFERENCES units(id) ON DELETE RESTRICT,
  to_unit_id bigint NOT NULL CONSTRAINT unit_conversions_to_unit_id_fk REFERENCES units(id) ON DELETE RESTRICT,
  factor numeric(20,10) NOT NULL CONSTRAINT unit_conversions_factor_chk CHECK (factor > 0),
  CONSTRAINT unit_conversions_pk PRIMARY KEY (from_unit_id, to_unit_id);
  CONSTRAINT unit_conversions_units_differ_chk CHECK (from_unit_id <> to_unit_id)
  );

CREATE TABLE material_unit_conversions (
  material_id bigint NOT NULL CONSTRAINT material_unit_conversions_material_id_fk REFERENCES materials(id) ON DELETE CASCADE,
  from_unit_id bigint NOT NULL CONSTRAINT material_unit_conversions_from_unit_id_fk REFERENCES units(id) ON DELETE RESTRICT,
  factor numeric(20,10) NOT NULL CONSTRAINT material_unit_conversions_factor_chk CHECK (factor > 0),
  CONSTRAINT material_unit_conversions_pk PRIMARY KEY (material_id, from_unit_id) 
  );
