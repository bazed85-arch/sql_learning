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

### Nullability

The test: **can a row exist meaningfully without this value at insert time?**

| `NOT NULL` | nullable |
|---|---|
| The row is meaningless without it | The value may be unknown or not applicable |
| Closed reference list, filled in once | Business attribute, filled in by a user |
| `units.code`, `materials.name`, `deliveries.supplier_id` | `materials.article_no`, `suppliers.tax_id`, `sites.actual_end_date` |

`UNIQUE` and nullable combine deliberately: PostgreSQL treats NULLs as distinct by
default, so a `UNIQUE` column accepts any number of them
([5.4.3](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-UNIQUE-CONSTRAINTS)).
Article numbers are unique when present; materials without one are unrestricted.

`sites.actual_end_date` is the cleanest case: NULL means "not finished yet" — a
meaningful answer, not missing data.
---

## Tables

### 1. `units` — units of measure

| Column | Type | Constraints | Comment |
|---|---|---|---|
| `id` | `bigint` | PK, generated always as identity | |
| `code` | `text` | `UNIQUE`, `NOT NULL`, `CHECK (code = lower(trim(code)))` | NOT NULL because the code *is* the unit — a row without it cannot be displayed anywhere: not on a delivery note, not in an estimate, not in a dropdown. Also a closed reference list, filled in once, so there is no state where a unit exists but its code is unknown. Contrast with `materials.article_no`, which is nullable |
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
| `article_no` | `text` | `UNIQUE`, nullable | Our own article number — what people actually say out loud. Nullable: a material can be created before a number is assigned |
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

### 8. `deliveries` — delivery events
 
| Column | Type | Constraints | Comment |
|---|---|---|---|
| `id` | `bigint` | PK, generated always as identity | |
| `supplier_id` | `bigint` | `NOT NULL`, FK → `suppliers.id`, `ON DELETE RESTRICT` | Who delivered. A supplier exists independently of any delivery |
| `delivery_note_number` | `text` | `NOT NULL` | The supplier's own document number |
| `delivery_date` | `date` | `NOT NULL` | Goods receipt is a calendar fact, not an instant |
| `status` | `text` | `NOT NULL`, `CHECK (status IN ('draft','received','received_with_issues','rejected'))` | State of the document, not a calculation |
| `notes` | `text` | nullable | |
| `created_at` | `timestamptz` | `NOT NULL DEFAULT now()` | When the row entered the system |
 
Additional constraint: `UNIQUE (supplier_id, delivery_note_number)`.
 
**Why not a global `UNIQUE` on the note number.** It is the *supplier's* numbering.
Supplier A issues note 1024, supplier B also issues note 1024 — both are valid.
Uniqueness is scoped to the parent, the same shape as `UNIQUE (estimate_id, line_no)`.
 
**No `site_id` and no `estimate_id` on this table.**
A delivery may carry materials for more than one site (recorded assumption 1), so a
site reference on the header would contradict it. An estimate belongs to one site, so
`estimate_id` here would contradict it too — and it would make deliveries outside any
estimate impossible to record.
 
**No completeness status.** Whether a delivery is full or partial is derived by
comparing quantities, not stored. See the note under `delivery_items`.
 
---
 
### 9. `delivery_items` — delivery note lines
 
| Column | Type | Constraints | Comment |
|---|---|---|---|
| `id` | `bigint` | PK, generated always as identity | |
| `delivery_id` | `bigint` | `NOT NULL`, FK → `deliveries.id`, **`ON DELETE CASCADE`** | A line has no meaning without its delivery note |
| `site_id` | `bigint` | `NOT NULL`, FK → `sites.id`, **`ON DELETE RESTRICT`** | Resolves the many-to-many between deliveries and sites |
| `material_id` | `bigint` | `NOT NULL`, FK → `materials.id`, `ON DELETE RESTRICT` | A material exists independently |
| `line_no` | `int` | `NOT NULL`, `CHECK (line_no > 0)` | Rows have no inherent order in a relation |
| `description` | `text` | nullable | What is printed on the note; may differ from the catalogue name |
| `unit_id` | `bigint` | `NOT NULL`, FK → `units.id` | The unit written on the note — may differ from the catalogue unit |
| `quantity` | `numeric(14,3)` | `NOT NULL`, `CHECK (quantity > 0)` | Quantity actually received. Input value |
| `unit_price` | `numeric(14,2)` | `NOT NULL`, `CHECK (unit_price >= 0)` | Frozen copy — describes the event, not the entity |
| `total` | `numeric(14,2)` | `GENERATED ALWAYS AS (quantity * unit_price) STORED` | PostgreSQL 17 supports STORED only |
| `created_at` | `timestamptz` | `NOT NULL DEFAULT now()` | |
 
Additional constraint: `UNIQUE (delivery_id, line_no)`.
 
**Surrogate key, not a composite `(delivery_id, site_id)`.** A composite PK requires the
pair to be unique by the nature of the data. It is not here: one truck delivers cement
and rebar to the same site on the same note — two rows, identical pair. The junction
form used in `supplier_materials` does not transfer, because there the
supplier/material pair genuinely is unique.
 
**`CASCADE` on `delivery_id`, `RESTRICT` on `site_id`.** Deleting a delivery note should
remove its lines. Deleting a site must never erase years of purchase history — a site
is an independent entity.
 
**No planned quantity, no outstanding quantity.**
 
| Value | Where it lives |
|---|---|
| Planned | `estimate_items.quantity` |
| Actual | `delivery_items.quantity` |
| Outstanding | nowhere — derived: planned minus the sum of actual |
 
Storing the planned quantity on a delivery line would be a 3NF violation: it is
determined by the estimate, not by the delivery event. Duplicating it guarantees drift.
 
---

## Relationships

| From | To | Type | Implementation |
|---|---|---|---|
| `sites` | `estimates` | one-to-many | `estimates.site_id` |
| `estimates` | `estimate_items` | one-to-many | `estimate_items.estimate_id` |
| `suppliers` | `deliveries` | one-to-many | `deliveries.supplier_id` |
| `deliveries` | `delivery_items` | one-to-many | `delivery_items.delivery_id` |
| `sites` | `delivery_items` | one-to-many | `delivery_items.site_id` |
| `materials` | `estimate_items` | one-to-many | `estimate_items.material_id` |
| `materials` | `delivery_items` | one-to-many | `delivery_items.material_id` |
| `units` | `materials` | one-to-many | `materials.unit_id` |
| `units` | `estimate_items` | one-to-many | `estimate_items.unit_id` |
| `units` | `delivery_items` | one-to-many | `delivery_items.unit_id` |
| `suppliers` ↔ `materials` | — | **many-to-many** | resolved through `supplier_materials` |
| `deliveries` ↔ `sites` | — | **many-to-many** | resolved through `delivery_items` |
 
General rule applied throughout: **the foreign key always sits on the "many" side.**
Cardinality must be tested in both directions before placing it.
 
**Note on `delivery_items`.** It carries three roles at once: child of a delivery note,
reference to a material, and resolution of the many-to-many between deliveries and
sites. A junction table does not always have to be created on purpose — a document-lines
table often already resolves a many-to-many by its own structure.
 
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
4. **Delivery note numbers are unique per supplier, not globally.**
5. **A delivery may be recorded without reference to any estimate.**
   Consumables and off-estimate purchases are normal.
6. **The unit on a delivery line may differ from the catalogue unit.**
   The note records what the supplier wrote. Conversion is deferred (see Block 2).
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
- - **Direct link between `delivery_items` and `estimate_items`** — a nullable
  `estimate_item_id`. Would allow the outstanding balance to be broken down per
  estimate line, and would catch deliveries of materials not on any estimate.
  Not added now: it requires the storekeeper to pick an estimate line at goods
  receipt, which is unrealistic in the first version.
- **Purchase orders** (`purchase_orders`, `purchase_order_items`) — the step between
  an estimate and a delivery. Deliberately out of scope; the schema currently assumes
  deliveries are recorded against sites directly.
- **`unit_id` on `supplier_materials`** — needed if supplier quoting units differ
  from catalogue units.
