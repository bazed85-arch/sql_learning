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

[5.5.5 Foreign Keys](https://www.postgresql.org/docs/17/ddl-constraints.html#DDL-CONSTRAINTS-FK)

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

[5.5.5 Foreign Keys](https://www.postgresql.org/docs/17/ddl-constraints.html#DDL-CONSTRAINTS-FK)

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

### A5. Composite primary key copied by resemblance
 
```
delivery_items:
  delivery_id — PK (composite)
  site_id     — PK (composite)
```
 
Written with the note *"I can't explain why, but I think these lines should be like this."*
 
**Wrong because:** a composite PK guarantees the pair is unique. Test it on two rows:
 
| delivery_id | site_id | material |
|---|---|---|
| 5 | 3 | cement |
| 5 | 3 | rebar | ← duplicate key, insert fails |
 
One truck delivering two materials to one site becomes impossible.
 
The form was copied from `supplier_materials`, where the composite PK is correct
because one supplier gives one price for one material — the pair genuinely is unique.
Surface similarity between two "junction-looking" tables is not evidence.
 
**Rule:** use a composite PK only when the combination is unique **by the nature of the
data**. Verify with a two-row example before writing it down.
 
**Correct form here:** surrogate `id` plus `line_no`, with `UNIQUE (delivery_id, line_no)` —
the same shape as `estimate_items`.
 
---
 
### A6. New foreign key contradicting an already recorded decision
 
Added `estimates.id` as a `NOT NULL` FK on `deliveries`, after having already recorded
assumption 1: *a delivery may carry materials for more than one site*.
 
**Wrong because:** an estimate belongs to one site. A delivery tied to one estimate is
therefore tied to one site — which cancels the decision that put `site_id` on the lines.
A schema cannot assert both.
 
Second failure: `NOT NULL` made it impossible to record a delivery of consumables
bought outside any estimate.
 
Third: assumption 2 already stated the outstanding balance is computed per
(site, material), so the estimate reference serves no purpose.
 
**Rule:** every new relationship is checked against the assumptions already written
down. If it contradicts one, either the FK is wrong or the assumption needs revising —
explicitly, not silently.
 
---
 
### A7. Missing participant in an event table
 
`deliveries` was written without `supplier_id`. The table recording deliveries did not
record who delivered. "How much did we buy from this supplier last quarter" was
unanswerable from the schema.
 
**Root cause:** started from one relationship (`estimate_id`) and stopped, instead of
enumerating the participants.
 
**Rule:** an event table has participants — **who, to whom, when, what**. List them
explicitly before writing any column.
 
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

[5.5.3 Unique Constraints](https://www.postgresql.org/docs/17/ddl-constraints.html#DDL-CONSTRAINTS-UNIQUE-CONSTRAINTS) ·
[5.5.4 Primary Keys](https://www.postgresql.org/docs/17/ddl-constraints.html#DDL-CONSTRAINTS-PRIMARY-KEYS)
---

### B2. `CHECK` referencing another table

```
CHECK material_id = materials.id
```

**Wrong because:** a check constraint expression evaluates over **the row being
inserted or updated**, using only that row's own columns. Cross-table rules are
enforced by foreign keys, or by triggers — never by `CHECK`.

[5.5.1 Check Constraints](https://www.postgresql.org/docs/17/ddl-constraints.html#DDL-CONSTRAINTS-CHECK-CONSTRAINTS)

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

### B5. `ON DELETE CASCADE` on an independent entity — repeat of B3
 
```
delivery_items.site_id — ON DELETE CASCADE
```
 
Justified as "a line has no meaning without its site". Logically true, but `CASCADE`
means: delete a site, and every delivery line ever recorded against it disappears.
Three years of purchase history removed by one statement.
 
**Rule, restated:** `CASCADE` follows *document structure* (lines under their document).
`RESTRICT` protects *independent entities* (sites, suppliers, materials). The question
is not "does the row make sense without the parent" but "does the parent exist in its
own right".
 
Second occurrence of this error. Watch it.
 
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

[5.4 Generated Columns](https://www.postgresql.org/docs/17/ddl-generated-columns.html)
---

### C3. Not knowing which generation mode is available

- PostgreSQL 12–17: **`STORED` only**. `VIRTUAL` raises an error.
- PostgreSQL 18+: `VIRTUAL` added, and it is the **default** when the keyword is omitted.

This project runs 17.6 → `STORED`.
Always write the keyword explicitly: omitting it is version-dependent behaviour.

---

### C4. Expecting a column to pull a value from another table
 
Two instances in one table:
- `unit_id` — *"I want to take units.id from here"*
- `quantity` — *"I don't know how to link it so the quantity fills in automatically"*
**Wrong because:** a column stores a value; it does not fetch one. Generation
expressions cannot reference other tables, and no other column type does either.
Copying a default at insert time is the **application's** job, not the schema's.
 
`delivery_items.quantity` is the quantity actually received — a storekeeper counts it
and types it. The database cannot know what was on the truck.
 
**Rule:** if the value comes from outside the row, it is either a stored copy written
at insert time, or a join at read time. Never an automatic column.
 
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

### D4. Planned and actual quantity in the same row
 
Proposed adding "delivered planned" and "delivered actual" columns to `delivery_items`.
 
**Wrong because:** the planned quantity is determined by the estimate, not by the
delivery event. Storing it on a delivery line duplicates it and guarantees drift —
the same failure as D1.
 
| Value | Where it belongs |
|---|---|
| Planned | `estimate_items.quantity` |
| Actual | `delivery_items.quantity` |
| Outstanding | nowhere — derived |
 
The same applies to a "fully / partially delivered" status: completeness is the result
of comparing sums, not a fact about the note. A `status` column is still justified, but
for the **state of the document** (received, received with issues, rejected), not for a
calculation.
 
**Rule:** a derived value is not stored unless there is a specific reason. Ask what
determines it — if the answer is another table, it does not belong here.
 
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

[8.1.2 Arbitrary Precision Numbers](https://www.postgresql.org/docs/17/datatype-numeric.html)

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

[8.5 Date/Time Types](https://www.postgresql.org/docs/17/datatype-datetime.html)
---

### E6. Answering a different question than the one asked

- Asked "composite PK or surrogate, and why?" → picked one silently, gave no reasoning.
- Asked "what does `UNIQUE (number, version)` do?" → explained what the `version`
  column means instead of what the constraint enforces.
- Asked "place `site_id`" → answered the cardinality question and stopped.

A cardinality answer is a step toward the decision, not the decision.

---

### E7. "I can't explain why, but I think it should be like this"
 
Written verbatim about the composite PK in A5.
 
**Not a small thing.** It is the signal that a form was copied rather than designed.
Every structure in a schema exists for a reason that can be stated in one sentence.
If the sentence does not come, the structure has not been checked.
 
**Rule:** a design line with no justification is a hypothesis, not a decision. Mark it
as an open question instead of writing it as settled.
 
Compare with what was done correctly on unit conversion earlier: *"conversion is needed
here, mechanism unclear"* — a marked gap costs nothing, an unverified construct costs
a lot.
 
---
 
### E8. Enumerated values written in the wrong language
 
```
CHECK (status IN (доставлен полностью, доставлен частично))
```
 
`CHECK` values end up in application code, in API responses, and in every query.
Use lowercase English identifiers: `('draft','received','received_with_issues','rejected')`.
UI labels are translated in the interface layer, not stored in the constraint.
 
Also in this table: `delivery_item_name` → `description`. Repeat of E3 — the table is
already the context.
 
---

## Recurring patterns to watch

1. **Cardinality in both directions, in writing, before placing any FK.**
2. **Entity or event?** — before deciding whether to store or reference a value.
3. **Four parts per column line** — name, type, constraints, justification.
4. **Verify the construct exists** before writing a constraint (`CHECK` across tables,
   `VIRTUAL` on PG 17).
5. **Finish the question that was asked**, including the "why".
6. **Test a composite PK on two example rows** before accepting it.
7. **Check every new FK against the recorded assumptions.**
8. **List the participants of an event** — who, to whom, when, what.
9. **`CASCADE` follows document structure, `RESTRICT` protects independent entities.**
10. **If the justification does not come out in one sentence, it is an open question,
    not a decision.**
---
 
## Scorecard — Topic 1
 
| | Count |
|---|---|
| Structural errors | 7 |
| Constraint errors | 5 |
| Generated column errors | 4 |
| Normalization errors | 4 |
| Specification discipline | 8 |
| **Total** | **28** |
 
Repeated after being flagged: B3→B5, C1→C4, D1→D2, E3→E8.
 
Applied a rule independently, without prompting: `unit_price` on `delivery_items`
stored as a frozen copy, justified as "event, not entity" (rule D2).
