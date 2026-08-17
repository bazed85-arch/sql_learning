# Mistakes Log — Block 1 · Topic 1

Errors made while designing the construction supply schema.
Format: **what I wrote → why it is wrong → the rule → source**.

---

## A. Structural errors

### A1. Circular foreign key

```
estimates.estimate_item_id  → FK to estimate_items.id
estimate_items.estimate_id  → FK to estimates.id
```

**Wrong because:** neither row can be inserted first. To create the estimate I need
an item id; to create the item I need an estimate id. Deadlock at row zero.
Worse, the design allows exactly one item per estimate — the table cannot represent
what it is named after.

**Rule:** in a one-to-many relationship the foreign key sits **only on the "many" side**.
The parent table carries no reference back to its children.

**Root cause:** I designed the child table first and let its needs shape the parent.
Design the parent first, then hang children off it.

[5.4.5 Foreign Keys](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-FK)

---

### A2. Skipping the cardinality question

I placed foreign keys without asking the question in both directions.

**Rule:** for every pair of entities, ask twice:
- Can one A have many B? 
- Can one B have many A?

Yes/No → one-to-many, FK on the "many" side.
Yes/Yes → many-to-many, junction table required.

Asking in one direction only is what produced A1.

---

### A3. Foreign key pointing at a value, not a key

```
estimate_item_price — FK price (supplier_materials)
```

**Wrong because:** `supplier_materials.price` is not unique — many rows hold 8.40.
A foreign key must reference a `PRIMARY KEY` or a `UNIQUE` column. "FK to a price"
is not a construct that exists.

**Rule:** foreign keys reference **keys**. If you want to record where a value came
from, reference the row (`supplier_material_id`) and store the value separately.

[5.4.5 Foreign Keys](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-FK)

---

### A4. Treating a foreign key as a role instead of an identifier

Answered "it references the latest version" / "it links to the latest estimate".

**Wrong because:** there is no "latest" in a relational database. There are rows with
different `id` values. A foreign key stores one specific number, written once, and it
never moves. If deliveries pointed at "the latest estimate", a March delivery would
retroactively attach to a document that did not exist in March.

**Rule:** FK = a concrete identifier. "Current", "latest", "active" are results of a
query (`WHERE status = 'approved'`), never something a column can mean.

---

## B. Constraint errors

### B1. `UNIQUE` used where `PRIMARY KEY` was meant

```
supplier_materials_id — bigint — unique
```

| | `UNIQUE` | `PRIMARY KEY` |
|---|---|---|
| Allows NULL | yes, multiple | no |
| Per table | any number | at most one |
| Default FK target | no | yes |

A `UNIQUE` column without `NOT NULL` can hold ten NULLs. That is not an identifier.

[5.4.3 Unique Constraints](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-UNIQUE-CONSTRAINTS) ·
[5.4.4 Primary Keys](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-PRIMARY-KEYS)

---

### B2. `CHECK` referencing another table

```
CHECK material_id = materials.id
```

**Wrong because:** a check constraint expression evaluates over **the row being
inserted or updated**, using only that row's own columns. Cross-table rules are
enforced by foreign keys, or by triggers — never by `CHECK`.

[5.4.1 Check Constraints](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-CHECK-CONSTRAINTS)

---

### B3. Applying `ON DELETE RESTRICT` uniformly

I used `RESTRICT` on every foreign key without asking which case each one was.

**Rule:**
- `CASCADE` — for rows with no independent meaning (`estimate_items` under an estimate)
- `RESTRICT` — for entities that exist on their own (`materials`, `suppliers`)

Deleting an estimate should remove its lines. Deleting a supplier must never silently
erase a year of delivery history.

---

### B4. `CHECK (quantity >= 0)` instead of `> 0`

A line with quantity zero is not a line, it is noise in the document.
Think about whether zero is a legitimate value, not just whether negatives are.

---

## C. Generated column errors

### C1. `quantity` declared as generated

Quantity is **input**. A person reads the drawings and types 200.
Nothing in the database can compute it.

---

### C2. `total` placed in a table that has no operands

```
estimates.total — generated always as quantity * price
```

**Wrong because:** `estimates` has neither `quantity` nor `price`. A generation
expression may reference **only other columns of the same row** — no subqueries,
no other tables, no aggregates, no other generated columns, and it must be immutable.

`quantity * unit_price` is valid on `estimate_items`, where both operands live in the row.
The **estimate total** is a sum across many rows — that is an aggregate, computed with
`SUM()` in a query or exposed through a view.

[5.4 Generated Columns](https://www.postgresql.org/docs/current/ddl-generated-columns.html)

---

### C3. Not knowing which generation mode is available

- PostgreSQL 12–17: **`STORED` only**. `VIRTUAL` raises an error.
- PostgreSQL 18+: `VIRTUAL` added, and it is the **default** when the keyword is omitted.

This project runs 17.6 → `STORED`.
Always write the keyword explicitly: omitting it is version-dependent behaviour.

---

## D. Normalization errors

### D1. `unit_price` placed on `materials`

**Wrong because:** `material_id → unit_price` is not a functional dependency.
Cement costs 8.40 at one supplier and 9.10 at another. The table can physically
store only one price per material — it cannot represent the business.

**Rule:** a column that is not functionally determined by the key does not belong
in that table.

Three different prices, three different tables:

| Price | Table | Determined by |
|---|---|---|
| Supplier's offer | `supplier_materials` | `(supplier_id, material_id)` |
| Estimated price | `estimate_items` | the estimate line |
| Price actually paid | `delivery_items` | the delivery line |

---

### D2. Reintroducing the same error as a foreign key

After removing the price from `materials`, I tried to make `estimate_items.unit_price`
a live reference to `supplier_materials`.

**Same mistake, different mechanism.** A live reference means an April price increase
silently rewrites a March estimate the client already signed.

**The test — entity or event?**
- The value describes the referenced entity (supplier's phone) → normalize it away
- The value describes the event (price agreed on this line) → store a frozen copy

This is the documented exception to 3NF for historical values, and it is the most
common serious modelling error in procurement systems.

---

### D3. Considering `new_price` as a way to keep price history

**Wrong because:** one extra column holds exactly one previous price. The third price
list has nowhere to go. There are no dates, so "what was the price on 15 March" is
unanswerable.

**Rule:** data that repeats over time grows **downward as rows**, never sideways
as columns. Same pattern as the 1NF violation `material_1, material_2, material_3`.

---

## E. Specification discipline

### E1. Incomplete column definitions

```
materials_id — relation to materials table
valid_to — null
```

Missing: data type, nullability, `ON DELETE` behaviour. `NULL` is a **value**, not a type.

**Rule:** every line needs four parts — **name, type, constraints, one-line justification**.
Three of six lines in that message could not be implemented as written.

Why it matters: an LLM given an ambiguous schema produces plausible-looking wrong
migrations, and the error is invisible unless you already decided what was right.

---

### E2. `numeric` without precision (repeated three times)

Bare `numeric` is valid — arbitrary precision — but `numeric(14,2)` enforces two decimal
places and documents intent.

Money → `numeric(14,2)`. Quantity → `numeric(14,3)`.

[8.1.2 Arbitrary Precision Numbers](https://www.postgresql.org/docs/current/datatype-numeric.html)

---

### E3. Plural foreign key names

`materials_id`, `suppliers_id` → the column holds **one** id.
FK columns are always singular: `material_id`, `supplier_id`.

Same principle: `materials.name`, not `materials.material_name`. The table is already
the context.

---

### E4. Three naming conventions in three tables

Used `materials.material_id`, `units.id`, and `supplier_materials_id` in the same schema.

**Chosen convention:** `id` for the primary key, `<singular>_id` for foreign keys.
Reason: Supabase generates `id` by default, PostgREST URLs read cleanly
(`/rest/v1/materials?id=eq.5`), and FlutterFlow expects `id`.

Mixed conventions across a schema are worse than either choice consistently applied.

---

### E5. `timestamptz` where `date` was correct

Used `timestamptz` for `valid_from` on a price list.

**Rule:** a price list is valid *from 1 April* — a calendar fact, not an instant → `date`.
`created_at` (when the row was inserted) is an instant → `timestamptz`.

Ask: **is this a moment in time, or a calendar day?**

[8.5 Date/Time Types](https://www.postgresql.org/docs/current/datatype-datetime.html)

---

### E6. Answering a different question than the one asked

- Asked "composite PK or surrogate, and why?" → picked one silently, gave no reasoning.
- Asked "what does `UNIQUE (number, version)` do?" → explained what the `version`
  column means instead of what the constraint enforces.
- Asked "place `site_id`" → answered the cardinality question and stopped.

A cardinality answer is a step toward the decision, not the decision.

---

## Recurring patterns to watch

1. **Cardinality in both directions, in writing, before placing any FK.**
2. **Entity or event?** — before deciding whether to store or reference a value.
3. **Four parts per column line** — name, type, constraints, justification.
4. **Verify the construct exists** before writing a constraint (`CHECK` across tables,
   `VIRTUAL` on PG 17).
5. **Finish the question that was asked**, including the "why".
