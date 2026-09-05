-- seed.sql — minimal test data for the construction supply schema
--
-- Applied separately from migrations. Migrations describe structure and must run
-- on any database; this file is test data and belongs only on development ones.
--
-- ASSUMES A CLEAN DATABASE. Surrogate ids are not written out — they come from the
-- identity sequences, so `materials.unit_id` below relies on `units` receiving
-- ids 1, 2, 3 in insertion order. Referencing units by `code` instead needs a
-- subquery; revisit once SELECT is covered. See notes.md, open question 2.
 
-- units -----------------------------------------------------------------------
 
INSERT INTO units (code, name, sort_order) VALUES
  ('m3',  'cubic meter', 1),   -- expected id 1
  ('kg',  'kilogram',    2),   -- expected id 2
  ('pcs', 'pieces',      3);   -- expected id 3
 
-- materials -------------------------------------------------------------------
-- article_no is nullable: a material may exist before a number is assigned.
-- It must be NULL, never '' — an empty string is a value and collides under
-- UNIQUE, which would allow only one article-less material in the whole catalogue.
 
INSERT INTO materials (article_no, name, unit_id) VALUES
  ('CEM II/B-L', 'CEMENT', 2),
  (NULL, 'PHONIQUE plasterboard 2500x1200x13 mm', 3);
