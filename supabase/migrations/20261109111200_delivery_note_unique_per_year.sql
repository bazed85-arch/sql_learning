ALTER TABLE deliveries ADD COLUMN year_no int GENERATED ALWAYS AS EXTRACT(YEAR FROM delivery_date)::int;
ALTER TABLE deliveries DROP CONSTRAINT deliveries_supplier_id_delivery_note_number_uq;
ALTER TABLE deliveries ADD CONSTRAINT deliveries_supplier_id_delivery_note_number_year_no_uq UNIQUE (supplier_id, delivery_note_number, year_no);
