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
  ('pcs', 'pieces',       1),    -- expected id 1
  ('bag', 'bag',          2),    -- expected id 2
  ('kg',  'kilogram',     3),    -- expected id 3
  ('t',   'tonne',        4),    -- expected id 4
  ('m',   'meter',        5),    -- expected id 5
  ('m2',  'square meter', 6),    -- expected id 6
  ('m3',  'cubic meter',  7),    -- expected id 7
  ('l',   'liter',     NULL);    -- expected id 8; sort_order left NULL on purpose

-- materials -------------------------------------------------------------------
-- article_no is nullable: a material may exist before a number is assigned.
-- It must be NULL, never '' — an empty string is a value and collides under
-- UNIQUE, which would allow only one article-less material in the whole catalogue.
-- category is nullable: two rows below have none.

INSERT INTO materials (article_no, name, description, unit_id, category, is_active) VALUES
  ('CEM-II-425', 'Cement CEM II/B-L 42,5N', 'Bag 25 kg, palletised 1400 kg', 2, 'cement',     true),
  ('CEM-I-525',  'Cement CEM I 52,5R',       NULL,                            2, 'cement',     true),
  (NULL,         'PHONIQUE plasterboard 2500x1200x13 mm', 'Acoustic board',    1, 'drywall',    true),
  ('PLB-STD-13', 'Plasterboard standard 2500x1200x13 mm', NULL,               1, 'drywall',    true),
  ('REBAR-12',   'Rebar B500S 12 mm',        'Bars of 12 m',                  4, 'rebar',      true),
  ('REBAR-20',   'Rebar B500S 20 mm',        NULL,                            4, 'rebar',      true),
  (NULL,         'Sand washed 0/4',          NULL,                            4, 'aggregate',  true),
  ('GRAV-1220',  'Gravel 12/20',             NULL,                            7, 'aggregate',  true),
  ('INS-XPS-50', 'XPS insulation board 50 mm', NULL,                          6, 'insulation', true),
  ('PAINT-W-15', 'Facade paint white',       '15 l bucket',                   8, NULL,         true),
  ('SILIC-CLR',  'Silicone sealant clear',   NULL,                            1, NULL,         true),
  ('CEM-II-425-OLD', 'Cement CEM II/B-L 42,5N old packaging', 'Discontinued 2025', 2, 'cement', false);
