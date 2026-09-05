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
 
Remaining: `estimates`, `deliveries` (level 1), then `supplier_materials`,
`estimate_items`, `delivery_items` (level 2).
 
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
 
**2. `seed.sql` hardcodes `unit_id`.**
The file assumes a clean database where `units` receives ids 1, 2, 3. Referencing
units by `code` instead requires a subquery, and `SELECT` has not been covered yet.
Revisit after Topic 5.
 
**3. Carried over from Topic 1, still open.**
Estimate revisions (decision #2) and unit conversion. Both are changes to an existing
populated schema, so both belong to the `ALTER TABLE` step.
