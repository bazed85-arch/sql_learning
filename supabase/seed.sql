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

-- suppliers -------------------------------------------------------------------
-- tax_id is nullable and UNIQUE: two suppliers have none, which is only possible
-- because UNIQUE treats NULLs as distinct (Topic 2, experiment 2).
-- payment_terms_days is nullable: terms may be unagreed, which is not the same
-- as terms of zero — supplier 6 pays on delivery, supplier 3 has no agreement.

INSERT INTO suppliers (name, tax_id, contact_person, phone, email, payment_terms_days, is_active, notes) VALUES
  ('Cementos Especiales de Canarias SL', 'B38123456', 'Javier Melián',  '+34 922 61 20 14', 'pedidos@cecan.es',        30,  true,  'Main cement supplier, Granadilla plant'),
  ('Ferreteria Industrial Anaza',        'B38234567', 'Nuria Robaina',  '+34 922 20 44 91', NULL,                      15,  true,  NULL),
  ('Aridos del Sur SL',                  NULL,        NULL,             '+34 922 77 03 58', NULL,                      NULL, true,  'No written terms yet'),
  ('Pladur Distribucion Canarias',       'B35345678', 'Alberto Santana', NULL,              'ventas@pladurcan.es',     45,  true,  NULL),
  ('Hierros y Aceros Tinerfenos SA',     'A38456789', 'Cristina Perdomo','+34 922 53 18 76', 'comercial@hattsa.es',     60,  true,  'Rebar, 12 m bars, own transport'),
  ('Suministros La Laguna',              NULL,        'Tomas Gonzalez', '+34 922 25 67 30', NULL,                      0,   true,  'Payment on delivery'),
  ('Pinturas Atlantico SL',              'B38567890', NULL,             NULL,               'info@pinturasatlantico.es', 30, false, 'Contract ended 2025'),
  ('Global Build Supplies Ltd',          'X1234567Z', 'Peter Hallam',   '+44 20 7946 0112', 'sales@globalbuild.co.uk', NULL, false, 'Import, terms per order');

-- sites -----------------------------------------------------------------------
-- actual_end_date is NULL while a site is unfinished — four of six rows.
-- start_date is NULL for a site that has not begun; planned_end_date is NULL
-- for one that was suspended before a date was agreed.

INSERT INTO sites (code, name, address, status, start_date, planned_end_date, actual_end_date) VALUES
  ('TF-001', 'Residencial Las Chafiras',      'Poligono Las Chafiras, San Miguel de Abona', 'active',    '2025-03-10', '2026-06-30', NULL),
  ('TF-002', 'Nave Industrial Guimar',        'Poligono Industrial de Guimar, parcela 14',  'completed', '2024-09-02', '2025-05-15', '2025-06-20'),
  ('TF-003', 'Hotel Costa Adeje reforma',     'Avda. Bruselas 12, Costa Adeje',             'active',    '2026-01-15', '2026-12-20', NULL),
  ('TF-004', 'Edificio Santa Cruz oficinas',  NULL,                                         'suspended', '2025-11-04', NULL,         NULL),
  ('TF-005', 'Ampliacion Puerto Los Cristianos', NULL,                                      'planned',   NULL,         '2027-03-01', NULL),
  ('TF-006', 'Viviendas La Orotava',          'Calle El Calvario 8, La Orotava',            'completed', '2024-02-19', '2025-01-31', '2025-01-20');

-- unit_conversions ------------------------------------------------------------
-- Material-independent factors only: 1 from_unit = factor to_unit.
-- One direction per pair: kg -> t is derived as 1 / factor from the t -> kg row.
-- Storing both would record one fact twice, and a CHECK sees a single row, so
-- nothing could keep the two consistent.
-- Pairs such as kg -> m3 are absent on purpose: mass converts to volume only
-- through a material's density. Material-dependent factors (a bag of cement
-- vs a bag of gravel) belong in material_unit_conversions.

INSERT INTO unit_conversions (from_unit_id, to_unit_id, factor) VALUES (4, 3, 1000);  -- t  -> kg
INSERT INTO unit_conversions (from_unit_id, to_unit_id, factor) VALUES (7, 8, 1000);  -- m3 -> l
