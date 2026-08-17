# Construction Supply Database — Schema Design

**Block 1 · Topic 1 — Relational model & schema design**
Target DBMS: PostgreSQL 17.6 (Supabase)
Status: design only — no SQL, no migrations yet.

Domain: construction sites, cost estimates, suppliers, deliveries.

---

## Conventions

| Element | Rule | Example |
|---|---|---|
| Tables | `snake_case`, plural | `estimate_items` |
| Primary key | always `id` | `estimates.id` |
| Foreign key | `<referenced_table_singular>_id` | `site_id`, `supplier_id` |
| Columns | `snake_case`, singular | `unit_price`, `lead_time_days` |
| Booleans | `is_` / `has_` prefix | `is_active` |
| Timestamps | `_at` suffix | `created_at` |
| Dates | `_date` / `_from` / `_to` suffix | `delivery_date` |
| Junction tables | both entity names | `supplier_materials` |

Reason for `snake_case`: PostgreSQL folds unquoted identifiers to lower case
([4.1.1 Identifiers and Key Words](https://www.postgresql.org/docs/current/sql-syntax-lexical.html)).
`supplierMaterials` silently becomes `suppliermaterials` unless quoted everywhere.

### Type conventions

| Purpose | Type | Reason |
|---|---|---|
| Surrogate key | `bigint generated always as identity` | [5.3 Identity Columns](https://www.postgresql.org/docs/current/ddl-identity-columns.html) |
| Money | `numeric(14,2)` | Exact arithmetic. Never `double precision`, never `money` — [8.1.2](https://www.postgresql.org/docs/current/datatype-numeric.html) |
| Quantity | `numeric(14,3)` | Fractional units exist (2.5 t of sand) |
| String | `text` | No performance difference vs `varchar(n)` in PostgreSQL — [8.3](https://www.postgresql.org/docs/current/datatype-character.html) |
| Calendar day | `date` | A delivery date is a calendar fact, not a moment |
| Moment in time | `timestamptz` | Stores an absolute instant — [8.5.1.3](https://www.postgresql.org/docs/current/datatype-datetime.html) |
| Fixed value set | `text` + `CHECK` | Chosen over `enum`: altering a `CHECK` is trivial, altering an enum is not |

---

## Tables

### 1. `units` — units of measure

| Column | Type | Constraints | Comment |
|---|---|---|---|
| `id` | `bigint` | PK, generated always as identity | |
| `code` | `text` | `UNIQUE`, `NOT NULL`, `CHECK (code = lower(trim(code)))` | Natural key, enforced as UNIQUE — not as PK |
| `name` | `text` | `NOT NULL` | Full name shown in UI |
| `sort_order` | `int` | nullable | Controls dropdown order; alphabetical is wrong here |

Seed values: `pcs`, `bag`, `t`, `kg`, `m`, `m2`, `m3`, `l`.

**Decision:** separate table instead of a free-text column on `materials`.
Trade-off: costs a join on every material display, but new units are an `INSERT`
instead of an `ALTER TABLE`, and the table can carry attributes later.

---

### 2. `materials` — material catalogue

| Column | Type | Constraints | Comment |
|---|---|---|---|
| `id` | `bigint` | PK, generated always as identity | |
| `code` | `text` | `UNIQUE`, nullable | Internal article number — what people actually say out loud |
| `name` | `text` | `NOT NULL` | Not UNIQUE: same name from two manufacturers = different materials |
| `description` | `text` | nullable | Full spec: grade, dimensions, standard |
| `unit_id` | `bigint` | `NOT NULL`, FK → `units.id`, `ON DELETE RESTRICT` | Catalogue unit of measure |
| `category` | `text` | nullable | Avoids `LIKE '%cement%'` filtering |
| `is_active` | `boolean` | `NOT NULL DEFAULT true` | Soft delete — materials are referenced by history |
| `created_at` | `timestamptz` | `NOT NULL DEFAULT now()` | |

**No price column.** Price is not functionally determined by `material_id` —
the same material has different prices per supplier. See `supplier_materials`.

---

### 3. `suppliers`

| Column | Type | Constraints | Comment |
|---|---|---|---|
| `id` | `bigint` | PK, generated always as identity | Surrogate: tax id can change, row identity cannot |
| `name` | `text` | `NOT NULL` | Legal or trade name |
| `tax_id` | `text` | `UNIQUE`, nullable | Spanish NIF/CIF. `text` — leading zeros and letters exist. Multiple NULLs allowed by default |
| `contact_person` | `text` | nullable | |
| `phone` | `text` | nullable | Never numeric: `+34`, spaces, extensions |
| `email` | `text` | nullable | |
| `payment_terms_days` | `int` | `CHECK (payment_terms_days >= 0)`, nullable | 30, 60 — business rule enforced in DB |
| `is_active` | `boolean` | `NOT NULL DEFAULT true` | Soft delete — deliveries reference suppliers permanently |
| `notes` | `text` | nullable | |
| `created_at` | `timestamptz` | `NOT NULL DEFAULT now()` | |

---

### 4. `sites` — construction sites

| Column | Type | Constraints | Comment |
|---|---|---|---|
| `id` | `bigint` | PK, generated always as identity | |
| `code` | `text` | `UNIQUE`, `NOT NULL` | Human-readable site code used in daily conversation |
| `name` | `text` | `NOT NULL` | |
| `address` | `text` | nullable | |
| `status` | `text` | `NOT NULL`, `CHECK (status IN ('planned','active','suspended','completed'))` | |
| `start_date` | `date` | nullable | Calendar day, not a moment |
| `planned_end_date` | `date` | nullable | |
| `actual_end_date` | `date` | nullable | NULL = not finished. Correct use of NULL: not applicable yet |
| `created_at` | `timestamptz` | `NOT NULL DEFAULT now()` | |

---

### 5. `supplier_materials` — supplier price list (junction table)

Resolves the many-to-many relationship between `suppliers` and `materials`.

| Column | Type | Constraints | Comment |
|---|---|---|---|
| `supplier_id` | `bigint` | PK (composite), `NOT NULL`, FK → `suppliers.id`, `ON DELETE RESTRICT` | |
| `material_id` | `bigint` | PK (composite), `NOT NULL`, FK → `materials.id`, `ON DELETE RESTRICT` | |
| `supplier_article_no` | `text` | nullable | Supplier's own code — quoted on every purchase order |
| `price` | `numeric(14,2)` | `NOT NULL`, `CHECK (price >= 0)` | Current offer only |
| `currency` | `text` | `NOT NULL DEFAULT 'EUR'` | Cheap now, expensive to retrofit |
| `min_order_quantity` | `numeric(14,3)` | nullable, `CHECK (min_order_quantity > 0)` | Suppliers will not sell 3 bags |
| `lead_time_days` | `int` | nullable, `CHECK (lead_time_days >= 0)` | Key field for scheduling |
| `is_active` | `boolean` | `NOT NULL DEFAULT true` | Supplier stopped carrying the item |
| `created_at` | `timestamptz` | `NOT NULL DEFAULT now()` | |

**Primary key: `(supplier_id, material_id)`** — composite.
Canonical junction-table form: the pair is unique, neither column is unique alone.
The composite PK itself prevents duplicate supplier/material pairings.

Open question, not yet resolved: if the supplier quotes per tonne while the material
is catalogued in bags, this table needs its own `unit_id`.

---

### 6. `estimates` — cost estimates

| Column | Type | Constraints | Comment |
|---|---|---|---|
| `id` | `bigint` | PK, generated always as identity | |
| `site_id` | `bigint` | `NOT NULL`, FK → `sites.id`, `ON DELETE RESTRICT` | FK sits on the "many" side |
| `number` | `text` | `UNIQUE`, `NOT NULL` | Human-readable document number |
| `status` | `text` | `NOT NULL`, `CHECK (status IN ('draft','sent','approved','rejected'))` | |
| `estimate_date` | `date` | `NOT NULL` | Calendar fact |
| `valid_until` | `date` | nullable | |
| `currency` | `text` | `NOT NULL DEFAULT 'EUR'` | |
| `notes` | `text` | nullable | |
| `created_at` | `timestamptz` | `NOT NULL DEFAULT now()` | |

**No FK to `estimate_items`.** One estimate has many items; one item belongs to one
estimate. The single `estimate_id` on the child expresses the whole relationship.
An FK in both directions would be a circular reference — neither row could be inserted first.

**No `total` column.** The estimate total is an aggregate across many rows.
Generated columns cannot reference other rows or tables
([5.4 Generated Columns](https://www.postgresql.org/docs/current/ddl-generated-columns.html)).
Compute with `SUM()` in a query or expose through a view.

---

### 7. `estimate_items` — estimate lines

| Column | Type | Constraints | Comment |
|---|---|---|---|
| `id` | `bigint` | PK, generated always as identity | |
| `estimate_id` | `bigint` | `NOT NULL`, FK → `estimates.id`, **`ON DELETE CASCADE`** | A line has no meaning without its estimate |
| `material_id` | `bigint` | `NOT NULL`, FK → `materials.id`, **`ON DELETE RESTRICT`** | A material exists independently — never erase history |
| `line_no` | `int` | `NOT NULL`, `CHECK (line_no > 0)` | Rows have no inherent order in a relation |
| `description` | `text` | nullable | What is printed on this line; may differ from catalogue name |
| `unit_id` | `bigint` | `NOT NULL`, FK → `units.id` | Copied from the material, can be overridden |
| `quantity` | `numeric(14,3)` | `NOT NULL`, `CHECK (quantity > 0)` | Input value — cannot be generated |
| `unit_price` | `numeric(14,2)` | `NOT NULL`, `CHECK (unit_price >= 0)` | **Frozen copy, not a foreign key** — see below |
| `total` | `numeric(14,2)` | `GENERATED ALWAYS AS (quantity * unit_price) STORED` | PostgreSQL 17 supports STORED only; VIRTUAL arrived in 18 |
| `created_at` | `timestamptz` | `NOT NULL DEFAULT now()` | |

Additional constraint: `UNIQUE (estimate_id, line_no)`.

**Why `unit_price` is stored and not referenced — the 3NF exception.**
It looks like a transitive dependency, since a price is reachable through
`material_id` → `supplier_materials`. It is not.

The test: *does the value describe the referenced entity, or the event?*
A supplier's phone number describes the supplier → normalize it away.
The price agreed in an estimate describes **that estimate** → store it.
If the price were a live reference, a supplier's April price increase would
silently change a March estimate the client had already signed.

**`ON DELETE` choice, same rule applied twice:**
`CASCADE` for rows with no independent meaning, `RESTRICT` for entities that exist
on their own. Applying one behaviour uniformly is the mistake.

---

## Relationships

| From | To | Type | Implementation |
|---|---|---|---|
| `sites` | `estimates` | one-to-many | `estimates.site_id` |
| `estimates` | `estimate_items` | one-to-many | `estimate_items.estimate_id` |
| `units` | `materials` | one-to-many | `materials.unit_id` |
| `units` | `estimate_items` | one-to-many | `estimate_items.unit_id` |
| `materials` | `estimate_items` | one-to-many | `estimate_items.material_id` |
| `suppliers` ↔ `materials` | — | **many-to-many** | resolved through `supplier_materials` |

General rule applied throughout: **the foreign key always sits on the "many" side.**
Cardinality must be tested in both directions before placing it.

---

## Pending

- `deliveries` — delivery events
- `delivery_items` — delivery note lines; `site_id` sits here (resolves the
  many-to-many between deliveries and sites)

---

## Assumptions recorded

1. **A delivery may carry materials for more than one site.**
   Therefore `site_id` belongs on `delivery_items`, not on `deliveries`.
   Cost: "all deliveries to site X" requires a join through the lines.
2. **Outstanding quantity is calculated per (site, material) pair.**
   No direct link between `delivery_items` and `estimate_items`.
   Known limitation: cannot break the balance down by estimate line when the same
   material appears in two lines, and cannot allocate across two estimates for one site.
3. **One supplier has one address.** If warehouses multiply, this becomes a
   one-to-many relationship to a separate `addresses` table.

---

## Deferred to Block 2

Not omissions — scope decisions. Each is out of scope for "relational model and
schema design", and each will be added as a migration exercise later.

- **Price history** — `valid_from` / `valid_to` on `supplier_materials`
  (temporal table / slowly changing dimension type 2). Adding it changes the PK
  to `(supplier_id, material_id, valid_from)`.
- **Estimate versioning** — a revised estimate becomes a new row with its own
  copy of the item lines, not an `UPDATE`. Requires `version`, a `superseded`
  status, and `UNIQUE (number, version)`.
- **Unit conversion** — the factor depends on the material, not on the unit pair
  alone (1 t of rebar 12 mm = 1124 m; 1 t of rebar 20 mm = 405 m). A generated
  column cannot solve it: generation expressions cannot reference other tables.
- **`EXCLUDE` constraint** with `daterange` and `btree_gist` to prevent
  overlapping validity periods.
- **Indexes** — PK indexes are created automatically, FK indexes are **not**.
- **`unit_id` on `supplier_materials`** — needed if supplier quoting units differ
  from catalogue units.
