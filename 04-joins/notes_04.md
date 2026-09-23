# Notes — Topic 4, JOIN
 
Working notes: what was put into the database and why, what was checked against a
live database, what is still open.
 
---
 
## 1. Seed: seven tables filled
 
The four tables of topic 3 (`units`, `materials`, `suppliers`, `sites`, 34 rows)
were joined by seven more, 59 rows. Total 93 rows in eleven tables.
 
Insert order follows the foreign keys. Only two of the eight references constrain
the order of the new blocks, because the other six point at tables already filled
above in `seed.sql`:
 
- `estimate_items.estimate_id` → `estimates.id`
- `delivery_items.delivery_id` → `deliveries.id`
Row counts, verified against the Supabase project `construction-supply`:
 
| Table | Rows | ids |
|---|---|---|
| `supplier_materials` | 13 | composite key, no identity |
| `unit_conversions` | 2 | composite key |
| `material_unit_conversions` | 4 | composite key |
| `estimates` | 6 | 1–6 |
| `estimate_items` | 12 | 1–12 |
| `deliveries` | 9 | 1–9 |
| `delivery_items` | 11 | 1–11 |
 
ids landed without gaps, so the hard-coded foreign keys in `seed.sql` point where
they are meant to.
 
---
 
## 2. What was planted, and which join it exposes
 
| Planted | Where | Exposes |
|---|---|---|
| Materials 9 and 12 with no supplier | `supplier_materials` | `LEFT JOIN` + `IS NULL` |
| Supplier 8 with no catalogue row and no delivery | `supplier_materials`, `deliveries` | the same from the other side |
| TF-005, TF-006 with no estimate | `estimates` | `LEFT JOIN` from `sites` |
| EST-2026-003 with no lines | `estimate_items` | `LEFT JOIN` from `estimates` |
| FIA-3320 with no lines | `delivery_items` | `LEFT JOIN` through three tables |
| Materials 1, 4, 5 with two suppliers each | `supplier_materials` | rows multiplied by a join; sums become wrong |
| Rejected estimate on TF-004, inactive row for supplier 7 | `estimates`, `supplier_materials` | `ON` versus `WHERE` |
| `supplier_article_no` NULL in 7 rows, equal to our `article_no` in 2 | `supplier_materials` | joining on a nullable column |
| Note `0457` from supplier 3 in 2025 and 2026 | `deliveries` | self-join; also an `ORDER BY` trap |
| Rebar estimated in kg, catalogued in t | `estimate_items` | join through both conversion tables |
| Delivery line to TF-003 dated before that site's `start_date` | `delivery_items` | a cross-table check that `CHECK` cannot express |
 
---
 
## 3. Experiments
 
**3.1 `NATURAL JOIN` of `estimate_items` and `supplier_materials` returns 0 rows.**
 
The two tables share two column names: `material_id` and `created_at`. `NATURAL`
joins on both. All twelve rows of `estimate_items` carry
`2026-09-21 09:04:21.795796+00`, all thirteen rows of `supplier_materials` carry
`2026-09-21 08:58:23.369399+00` — they were inserted in separate statements.
`timestamptz` compares down to the microsecond, so the second condition is false
everywhere.
 
Unresolved, not tested: if the whole seed ran in one transaction, `now()` would
return the same value for every row ([9.9.5](https://www.postgresql.org/docs/17/functions-datetime.html#FUNCTIONS-DATETIME-CURRENT)),
`created_at` would match, and the same query would return rows. The result of a
`NATURAL JOIN` here depends on how the data was loaded.
 
**3.2 Two output columns named `name` collapse into one.**
 
`SELECT s.name, m.name …` produced a single `name` key when the query was run
through a client that maps each row to an object; the supplier name was gone. The
table prefix does not reach the output label. Fixed with `AS supplier` /
`AS material`.
 
**3.3 `LEFT JOIN` + `IS NULL` on a nullable column gives a different answer.**
 
Same query, two `WHERE` clauses:
 
- `di.material_id IS NULL` → 2 rows — materials never delivered.
- `sm.supplier_article_no IS NULL` → 9 rows — 7 rows that do have a supplier but
  no supplier code, plus the 2 without a supplier.
Both run without error.
 
**3.4 Row multiplication, measured.**
 
Estimate 1 has 4 lines totalling 15080.00. Joined to `supplier_materials` on
`material_id` it returns 7 rows, and summing `estimate_items.total` over them gives
27520.00. Materials 1, 5 and 4 each have two suppliers.
 
---
 
## 4. Practice
 
- Predictions of row counts, all checked from both sides: `INNER JOIN` 6,
  `LEFT JOIN` 8, `ON` versus `WHERE` 6 versus 3, three tables 13, `CROSS JOIN` 48,
  self-join 2 then 1, `FULL OUTER JOIN` 9, `FULL OUTER JOIN` in task 4 16.
- Four written queries: four-table join with aliases and labels; materials never
  delivered; sites active or suspended with their approved estimates, keeping
  sites without one; catalogue against active supplier rows with
  `FULL OUTER JOIN`.
- Not done: PGExercises, section Joins. Carried over.
---
 
## 5. Open questions
 
1. **Four migrations stamped in the future.** `20261009133000`, `20261009210000`,
   `20261109111200`, `20261109151900` — month and day transposed, should be
   `20260910…` and `20260911…`. Harmless today only because the wrong order
   happens to match the right one. The next migration created by
   `supabase migration new` will sort before them. Rename before the next
   `db reset`; check `supabase migration list` first if they are already applied
   remotely.
2. **`…_create_suppliers_sites.sql.sql`** — double extension, rename with the
   above.
3. **`schema-design.md` has drifted from the migrations.** It describes a
   `revision` column and `UNIQUE (number, revision)` on `estimates`; the migration
   has neither, only `UNIQUE (number)`. The same document lists estimate
   versioning under "Deferred to Block 2", contradicting itself. It also says
   "All nine tables" where there are eleven. Where the two disagree, the migration
   is the truth.
4. **`seed.sql` still hard-codes surrogate ids.** Closing it no longer needs
   topic 6: `INSERT ... SELECT` with a join on natural keys (`units.code`,
   `sites.code`, `estimates.number`) would do it. Worth doing precisely because it
   breaks where the natural key is NULL — materials 3 and 7 have no `article_no`,
   suppliers 3 and 6 have no `tax_id` — which is the join-on-nullable-column
   lesson applied to our own data.
5. **No `CHECK` on date consistency in `sites`** (topic 2 debt, still open). And a
   related case that a `CHECK` cannot cover at all: delivery line 7 is dated before
   the `start_date` of the site it was delivered to. Cross-table rules need a
   different mechanism.
6. **`material_unit_conversions` has no constraint preventing
   `from_unit_id = materials.unit_id`,** the way `unit_conversions` forbids
   `from_unit_id = to_unit_id`. Same reason as 5: the comparison spans two tables.
---
 
## 6. How the tutoring should run (for the next chat)
 
Agreed during this topic, after the format turned out to cost more time than the
material:
 
- One question at a time. The question itself is one or two lines, and the data
  needed to answer it is in the same message.
- Every value in the data is named `table.column`. Each column header says what it
  holds: a value, a reference to another table's column, or a count.
- One documentation link plus two or three lines summarising it — no more. The
  summary repeats what the section says and contains no inferences; inferences are
  the student's job.
- Only terms that appear in the official documentation. Anything else is flagged as
  such.
- Tasks name the file, table and line explicitly. No "as above", "in the same
  style".
- Nothing outside the current topic, and nothing about constructions the query does
  not contain.
- Wrong answer: do not give the right one, do not explain — ask a narrowing
  question against the student's own data, until he answers or asks for the answer.
- Right answer: one word plus one sentence of why, then the next question.
- Seed formatting and comment wording are the tutor's job; the student supplies the
  content — why the data is what it is, in his own words.
- The mistakes log is kept silently and shown only in the topic summary.
