# Notes — Block 1 · Topic 2
 
Working notes for DDL, data types and constraints.
Experiment results, catalogue findings, open questions.
Rules extracted from these findings live in `rules.md`; errors in `mistakes.md`.
 
Database: Supabase project `construction-supply`, eu-central-1, PostgreSQL 17.6.1.
 
---
 
## Tables created so far
 
| Level | Tables | Migration |
|---|---|---|
| 0 | `units` | `<ts>_create_units.sql` |
| 0 | `suppliers`, `sites` | `<ts>_create_suppliers_sites.sql` |
| 1 | `materials` | `<ts>_create_materials.sql` |
| 1 | `estimates`, `deliveries` | `<ts>_create_estimates_deliveries.sql` |
| 2 | `supplier_materials` | `<ts>_create_supplier_materials.sql` |
| 2 | `estimate_items` | `<ts>_create_estimate_items.sql` |
| 2 | `delivery_items` | `<ts>_create_delivery_items.sql` |
| 1 | `unit_conversions` | `<ts>_unit_conversions.sql` |
| 2 | `material_unit_conversions` | `<ts>_unit_conversions.sql` |

Eleven tables. The nine of the original design plus two added during the
`ALTER TABLE` work.
---
 
## Experiment 1 — breaking every constraint
 
Each attempt was expected to fail. Codes and constraint names as reported by
PostgreSQL.
 
| # | Attempt | SQLSTATE | Constraint |
|---|---|---|---|
| 1 | duplicate `units.code` | `23505` unique_violation | `units_code_uq` |
| 2 | `units.code = 'M3'` (uppercase) | `23514` check_violation | `units_code_chk` |
| 3 | material without `name` | — | **passed**, see below |
| 4 | `materials.unit_id = 9999` | `23503` foreign_key_violation | `materials_unit_id_fk` |
| 5 | `DELETE` a referenced unit | `23503` foreign_key_violation | `materials_unit_id_fk` |
| 6 | `INSERT` with explicit `id` | `428C9` | identity `GENERATED ALWAYS` |
 
### Reference — violation codes
 
| Constraint | SQLSTATE | Class |
|---|---|---|
| `UNIQUE` | `23505` | 23 — integrity |
| `CHECK` | `23514` | 23 — integrity |
| `NOT NULL` | `23502` | 23 — integrity |
| `FOREIGN KEY`, both directions | `23503` | 23 — integrity |
| identity `GENERATED ALWAYS` | `428C9` | **42 — access rule** |
 
Two things to carry into the Edge Functions work:
 
- Attempts 4 and 5 violate the **same** constraint from opposite sides and return the
  **same** code. The direction is only distinguishable from the message text
  (`insert or update on table "materials"` vs `update or delete on table "units"`),
  not from the code.
- `428C9` is **not** in class 23. An error handler that catches class 23 as "all data
  errors" will miss it. Writing to a `GENERATED ALWAYS` column is a permission
  question, not a consistency question, and it is rejected before values are checked.

[Appendix A. Error Codes](https://www.postgresql.org/docs/17/errcodes-appendix.html)
 
### Why attempt 3 passed
 
The insert supplied `''`, not `NULL`. `NOT NULL` worked correctly — there was nothing
to reject. An empty string is a value: present, of type `text`, length zero.
`NULL` is the absence of a value.
 
Practical consequence: a FlutterFlow form with a blank field submits `""`, not `null`.
`NOT NULL` on `materials.name` does **not** protect against a nameless material
arriving from our own application. A row with an empty name entered the catalogue
through the normal path.
 
---
 
## Experiment 2 — NULL vs empty string under UNIQUE
 
`materials.article_no` is `UNIQUE` and nullable. Four inserts, one at a time.
 
| # | `article_no` | Predicted | Actual |
|---|---|---|---|
| 6a | `NULL` | pass | pass |
| 6b | `NULL` | **fail** | **pass** |
| 6c | `''` | pass | pass |
| 6d | `''` | fail | fail — `23505` on `materials_article_no_uq` |
 
Three NULLs coexisted in the column. Two empty strings did not.
 
**Mechanism.** `UNIQUE` forbids **equality**, tested with `=`.
 
- `'' = ''` → `true`. Second row rejected.
- `NULL = NULL` → `NULL`. Not `true`, not `false`. Comparing an unknown to an unknown
  yields unknown, so equality is never established, so the constraint is never
  violated — any number of times.
  
`UNIQUE` constrains only values that are **present**. Absent ones it does not see.
 
The error message is worth reading: `Key (article_no)=() already exists`. The
parentheses are empty, yet that emptiness *exists* and matched something. A `NULL`
could never produce this message.
 
[9.2 Comparison Functions and Operators](https://www.postgresql.org/docs/17/functions-comparison.html)
 
### One mechanism, three appearances
 
All three surprises this session come from the same fact.
 
| Situation | Expected | Actual |
|---|---|---|
| `CHECK (x >= 0)`, `x` absent | row rejected, or zero stored | `NULL >= 0` → `NULL`, row passes |
| `NOT NULL` on `name`, `''` supplied | rejected | `''` is a value, constraint not involved |
| `UNIQUE` on `article_no`, two `NULL`s | conflict | `NULL = NULL` → `NULL`, no conflict |
 
**Any comparison with `NULL` returns `NULL`, not `true` and not `false`.**
All three results follow from this without memorising the individual cases.
The `IS NULL` operator exists precisely because `= NULL` does not work.
 
---
 
## Experiment 3 — identity and the sequence
 
Sequence state before: `materials_id_seq.last_value = 10`, while the table held two
rows with ids 1 and 2. Eight numbers had been consumed by deleted rows and by
**failed** inserts.
 
A sequence does not roll back with its transaction. The number is issued before
constraints are checked, and a rejected insert has already spent it. The alternative
would hold a lock until commit and serialise concurrent writes — a higher price than
gaps are worth.
 
Two inserts, in order:
 
| Insert | Result |
|---|---|
| explicit `id = 100` via `OVERRIDING SYSTEM VALUE` | `id = 100`, sequence untouched |
| ordinary insert, `id` omitted | `id = **11**` — predicted 101 |
 
`last_value` after both: 11.
 
**What this leaves armed.** The sequence will hand out 12, 13, 14 … and after 88 more
inserts will reach 100, where a row already sits: `23505` on `materials_pk`. The
failure appears 88 normal operations after the cause, with nothing visible in between.
 
This is the mechanism behind `rules.md` 3.1. `GENERATED ALWAYS` does not forbid manual
insertion — it is permitted via `OVERRIDING SYSTEM VALUE`. It makes it **visible**:
three extra words, i.e. a deliberate decision. `BY DEFAULT` allows the same thing
silently, so any careless `INSERT` can plant the same mine.
 
Fix after a bulk import: `setval` on the sequence to the maximum existing id.
[9.17 Sequence Manipulation Functions](https://www.postgresql.org/docs/17/functions-sequence.html)
 
**Rule:** `id` identifies a row. It is not a counter and not an ordinal. Gaps are
normal. Never display it, never count with it, never assume it is contiguous.
Human-facing numbers are `estimates.number` and `deliveries.delivery_note_number`.
 
---
 
## Catalogue findings
 
Two facts read from `pg_constraint` that were never written in any migration.
 
**Omitted `ON UPDATE` is not "unspecified".** `materials_unit_id_fk` stores
`confdeltype = 'r'` (RESTRICT, written explicitly) and `confupdtype = 'a'`
(NO ACTION, supplied by the database). Silence in DDL always means something
concrete.
 
**No index on the referencing column.** After four tables the database holds four
indexes — `units_pk`, `units_code_uq`, `materials_pk`, `materials_article_no_uq` —
all backing a `PRIMARY KEY` or a `UNIQUE`. `materials.unit_id`, the column every
future JOIN will use, has none. `PRIMARY KEY` and `UNIQUE` create an index
automatically; `FOREIGN KEY` does not.

**Literals are cast to the column type when the constraint is created, not per row.**

Written as `CHECK (price >= 0)`, stored as `CHECK ((price >= (0)::numeric))`.
`price` is `numeric`, the literal is `int`, and comparison needs one type — so the
cast was resolved once, at parse time. Compare `lead_time_days >= 0`, stored
unchanged: the column is `int`, the literal is `int`, nothing to reconcile.

Reading the catalogue definition is therefore not the same as reading what was
written. Expect `IN (...)` to appear as `= ANY (ARRAY[...])` and literals to carry
explicit casts.

**A generated column's expression is stored where `DEFAULT` expressions are stored.**

`pg_attrdef` holds both. In `estimate_items`, `total` carries
`(quantity * unit_price)` and `created_at` carries `now()` — same catalogue, same
column. Only `pg_attribute.attgenerated` tells them apart: `s` for STORED, empty for
an ordinary column.

| | `DEFAULT` | `GENERATED ... STORED` |
|---|---|---|
| Evaluated | on INSERT, when no value is supplied | on every INSERT and on any UPDATE touching its operands |
| Own value accepted | yes | no |
| May reference other columns of the row | no | yes — that is the point |
| Independent afterwards | yes, UPDATE changes it like any column | no, recomputed |

Consequence: edit `quantity` in the app and `total` follows by itself. Edit `total`
and nothing happens — which is the guarantee the construct is there for.

`total` is also the only column in the table without `NOT NULL`, deliberately: an
expression over two `NOT NULL` operands cannot produce `NULL`, so the constraint would
be a declaration with no work to do.
 
---

## ALTER TABLE work — debts paid

**Open question 1 — closed.** Five `CHECK` constraints added against empty strings:
`units.name`, `suppliers.name`, `sites.name`, `materials.name`,
`materials.article_no`. Expression `length(trim(col)) > 0` throughout. All five
report `convalidated = true` — existing rows were checked and passed.

**Open question 4 — closed.** Delivery note numbers are now unique per supplier *and
year*:

```sql
ALTER TABLE deliveries
  ADD COLUMN year_no int GENERATED ALWAYS AS (EXTRACT(YEAR FROM delivery_date)::int) STORED,
  DROP CONSTRAINT deliveries_supplier_id_delivery_note_number_uq,
  ADD CONSTRAINT deliveries_supplier_id_delivery_note_number_year_no_uq
      UNIQUE (supplier_id, delivery_note_number, year_no);
```

One command, three actions — the third successfully referenced the column added by
the first.

**Known cost of this solution, recorded deliberately.** `year_no` exists *only* to
serve the constraint. No report needs it, no screen shows it, the application never
reads it. The alternative — a unique index on the expression
`EXTRACT(YEAR FROM delivery_date)` — avoids the column but cannot be written as a
table constraint in `CREATE TABLE`, so it cannot be documented in
`schema-design.md` alongside the others. The column was chosen for documentability,
and the redundancy is the price. Without this note the column will look like
something someone forgot to delete.

### Estimate revisions — Topic 1 decision #2, closed in the schema

```sql
ALTER TABLE estimates
  ADD COLUMN revision int NOT NULL DEFAULT 1,
  DROP CONSTRAINT estimates_number_uq,
  ADD CONSTRAINT estimates_number_revision_uq UNIQUE (number, revision),
  ADD CONSTRAINT estimates_revision_chk CHECK (revision > 0);
```

**Model shift worth stating plainly.** An "estimate" is now an abstraction — the set of
rows sharing a `number`. Only revisions exist physically. A row in `estimates` is no
longer an estimate; it is a version of one.

**Why `created_at` is not part of the key.** `(number, created_at)` would technically
work, but two revisions created in one transaction share a `created_at` to the
microsecond — `now()` does not advance inside a transaction — so the second would be
rejected. And a user says "version 2", not "the version from 14 March 11:42:07.318".
An explicit `revision int` is the key; `created_at` stays as a fact, not an identifier.

**`estimate_items` needed no change at all.** `estimate_id` references
`estimates.id` — the surrogate key of a *row*, i.e. of a revision. Revisions 1 and 2
are different rows with different ids, so lines attach to their own version
automatically. This is where the surrogate key pays for itself: had the FK referenced
`estimates.number`, the lines of both revisions would be indistinguishable.

### Unit conversion — Topic 1 open question, closed with two tables

Two kinds of conversion factor exist, and they are facts at different levels.

| | Determined by | Rows for a 500-material catalogue |
|---|---|---|
| `t → kg = 1000` | the pair of units | **1** |
| cement: `bag → 25` | material *and* unit | one per material that ships packaged |

A tonne is a thousand kilograms for cement, for sand, for rebar — the material is
irrelevant. A bag is 25 kg for cement and 30 kg for dry mix — the material is the
whole point. `bag` is not a unit of measure at all; it is packaging.

**Why not one table.** The packaging table can express everything, at a price: the
row `t → kg = 1000` would have to be repeated for every material, because in that
table a factor cannot exist without one. Five hundred identical rows stating one
fact. Correct one of them by mistake and 499 materials disagree with the 500th, with
no constraint able to notice — each row is individually valid.

**Why not the other one table.** `bag → kg` has no universal value, so the physical
table cannot hold it.

```sql
CREATE TABLE unit_conversions (
  from_unit_id bigint NOT NULL ... REFERENCES units(id) ON DELETE RESTRICT,
  to_unit_id   bigint NOT NULL ... REFERENCES units(id) ON DELETE RESTRICT,
  factor numeric(20,10) NOT NULL CHECK (factor > 0),
  PRIMARY KEY (from_unit_id, to_unit_id),
  CHECK (from_unit_id <> to_unit_id)
);

CREATE TABLE material_unit_conversions (
  material_id  bigint NOT NULL ... REFERENCES materials(id) ON DELETE CASCADE,
  from_unit_id bigint NOT NULL ... REFERENCES units(id) ON DELETE RESTRICT,
  factor numeric(20,10) NOT NULL CHECK (factor > 0),
  PRIMARY KEY (material_id, from_unit_id)
);
```

**Three decisions inside these two tables.**

*Inverse pairs are not stored.* `t → kg = 1000` is recorded; `kg → t = 0.001` is
computed as `1 / factor`. Storing both duplicates one fact: change the bag weight from
25 to 30 and forget the inverse, and the database asserts both 30 kg and 25 kg per bag
simultaneously. No constraint can catch it — a `CHECK` sees one row, and these are two.
The price is a more complicated query: look for the pair in either order and divide
when it is the reverse. Paid once in code, against a silent data divergence.

*`material_unit_conversions` has no `to_unit_id`.* The factor always converts into the
material's base unit, which is already in `materials.unit_id`. Keeping the column would
allow it to diverge from that, and a constraint tying them would have to compare two
tables — outside what `CHECK` can express, so it would need a trigger. Same rule that
governs `total`: a value derivable from others is not stored. Price: converting bags to
tonnes takes two steps, bags → kg here and kg → t in `unit_conversions`.

*`numeric(20,10)`, not `numeric(14,2)`.* A factor is a multiplier and its error is
multiplied by the whole quantity; money has a smallest indivisible unit and a factor
does not. One plasterboard sheet 2500×1200 is 3 m², so `m² → sheet` is 0.3333333333 —
a repeating fraction with no exact value. At scale 2 it becomes 0.33, and over 300
sheets that is a 9-sheet error invented by rounding.

**First table in the schema with two foreign keys into the same table.** Only the
column names make it readable: `from_unit_id` and `to_unit_id`. Named `unit_id_1` and
`unit_id_2` it would work identically and be impossible to understand.

---
 
## Design decisions taken
 
**Surrogate keys stay `bigint GENERATED ALWAYS AS IDENTITY` across the whole schema.**
`uuid` was considered and rejected. Criterion: can a row receive its id *before*
reaching the database? No — the server issues every id at insert time. Offline
creation of records is assumed not to be supported.
 
*This assumption belongs in `schema-design.md` → Assumptions, because if offline
work is ever required the entire surrogate key layer changes at once.*
 
Note that `auth.users.id` is `uuid` (Supabase-owned table). Any future FK to a user
will be a `uuid` column sitting next to `bigint` ones. That is correct: the type of a
foreign key follows the type of the key it references, not house style.
 
Full write-up of the trade-off: to be added at the end of the session.
 
---
 
## Open questions
 
**1. Empty strings are not blocked by `NOT NULL`.**
Needs `CHECK` constraints, and two different kinds:
 
- on mandatory text (`materials.name`, `units.name`, `sites.name`, `suppliers.name`)
  — forbid the empty string;
- on optional text with `UNIQUE` (`materials.article_no`) — forbid the empty string
  *instead of* `NULL`, otherwise the column silently means "only one material may
  lack an article number".

Requires `ALTER TABLE` on tables that already hold data. Deferred to the `ALTER TABLE`
step of this topic.

**Closed.** See "ALTER TABLE work — debts paid".
 
**2. `seed.sql` hardcodes `unit_id`.**
The file assumes a clean database where `units` receives ids 1, 2, 3. Referencing
units by `code` instead requires a subquery, and `SELECT` has not been covered yet.
Revisit after Topic 5.
 
**3. Carried over from Topic 1 — both closed.**
Estimate revisions (decision #2) — see "Estimate revisions" above.
Unit conversion — see "Unit conversion" above.

**4. `UNIQUE (supplier_id, delivery_note_number)` may be scoped too widely.**

The constraint stops the same delivery note being entered twice for one supplier —
the common mistake during goods receipt, so the intent is right.

But many suppliers reset their numbering each January. Note 1024 of 2026 and note
1024 of 2027 are two different documents that legitimately share a number. The
current constraint accepts the first and rejects the second — a year after the schema
was written, with nothing having changed to explain it.

Candidate fix: scope uniqueness to supplier **and** year. Same shape as
"unique within the parent vs globally", one level deeper.

Not urgent — no data yet. Decide before the system holds a second year of deliveries.

**Closed.** See "ALTER TABLE work — debts paid".

**5. `supplier_materials` has no surrogate key, and that is conditional.**

The composite PK `(supplier_id, material_id)` is the natural key and is minimal, so a
surrogate `id` would be a second identifier for the same row — redundant.

It stops being redundant the moment the **same pair must repeat**. Price history,
already listed under Deferred, does exactly that: supplier X / material Y gains a row
from January, one from April, one from September. The PK then has to widen to
`(supplier_id, material_id, valid_from)` or give way to a surrogate `id`.

Second, less obvious condition: if another table ever needs to reference a specific
price-list row, the child carries a two-column foreign key instead of one. Workable,
awkward as the schema grows

**6. Revisions exist; "the current revision" is not defined.**

The schema can now hold several versions of one estimate. Nothing says which one is in
force. Three things remain undecided, none of them solvable in DDL:

- *Which revision is current* — the highest number, or the highest among `approved`?
  A draft revision 4 must not displace an approved revision 3.
- *Who assigns the number* — currently the application must compute `max(revision) + 1`
  itself. Two concurrent attempts produce the same number and the second fails on the
  `UNIQUE`. The rejection is correct; the user still has to be shown something.
- *Status lives on the revision, not on the estimate.* One `number` may legitimately
  have an `approved` version 2 and a `draft` version 3 at the same time. That is a
  normal state, not an error.

Two candidate mechanisms for "current", with their failure modes:

| Approach | Danger |
|---|---|
| `is_current boolean` | nothing guarantees exactly one `true` per `number`. The app sets it on revision 3 and forgets to clear it on 2 — two current versions, and a report counts both. A plain `UNIQUE` cannot express "at most one `true` per group"; a partial unique index can, but again cannot be documented as a table constraint |
| compute on the fly | "highest revision" is not the same as "in force" — see the draft case above. The definition has to be qualified by status, and every read needs a grouped subquery |

Leaning toward computing it, with an explicit written definition of "in force": a flag
is easy to add later and hard to remove from a running system. Revisit after the
`SELECT` topic.
