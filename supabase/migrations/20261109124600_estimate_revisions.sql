ALTER TABLE estimates ADD COLUMN revision int NOT NULL DEFAULT 1, 
  DROP CONSTRAINT estimates_number_uq, 
  ADD CONSTRAINT estimates_number_revision_uq UNIQUE (number, revision);
