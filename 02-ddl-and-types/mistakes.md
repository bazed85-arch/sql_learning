# Mistakes Log — Block 1 · Topic 2
 
Errors made while implementing the construction supply schema in PostgreSQL.
Format: **what I wrote → why it is wrong → the rule → source**.
 
---
 
## A. Foreign key semantics
 
### A1. `ON DELETE` read as a rule about deleting the child row
 
Asked what `ON DELETE` to put on `deliveries.received_by_user_id → users.id`,
I answered: "deleting a delivery must not delete the user from the parent table,
so RESTRICT".
 
**Wrong because:** that scenario does not exist. Deleting a row in `deliveries`
cannot affect `users` under any setting, and no clause is needed to prevent it.
`ON DELETE` fires when a row is deleted in the **parent** table — the one being
referenced. The question it answers is: forty child rows are about to be left
pointing at nothing, what happens to them?
 
**Rule:** `ON DELETE` describes the fate of the **children** when a **parent**
disappears. The criterion for choosing stays rule 5.2 of Topic 1 — does the parent
exist in its own right?
 
**Root cause, and it explains Topic 1.** With the direction reversed, `CASCADE`
reads as "this row may be deleted", which makes it the natural choice for anything
not worth protecting. That is exactly what produced `CASCADE` on an independent
entity three times in Topic 1 (B3 → B5 → control question 10). The rule was written
down correctly; the model underneath it was wrong.
 
The answer RESTRICT was correct. It was reached from a reason that does not exist.
 
[5.5.5 Foreign Keys](https://www.postgresql.org/docs/17/ddl-constraints.html#DDL-CONSTRAINTS-FK)
 
---
 
## B. Constraint syntax
 
### B1. Constraint name placed after the constraint
 
```sql
id bigint PRIMARY KEY CONSTRAINT units_pk GENERATED ALWAYS AS IDENTITY
```
 
**Wrong because:** in the grammar, `[ CONSTRAINT name ]` is the **first** element of
a column constraint and binds to whatever follows it. Written this way, `PRIMARY KEY`
is a separate anonymous constraint and `units_pk` attaches to the identity clause,
where it is not stored at all. The statement runs; the primary key ends up with a
system-generated name — the one outcome the naming was meant to avoid.
 
**Rule:** `CONSTRAINT name` before the constraint keyword, always.
 
**Root cause:** wrote the elements in the order they came to mind instead of the
order in the syntax diagram. The same line one row below —
`code text CONSTRAINT units_code_uq UNIQUE NOT NULL CONSTRAINT units_code_chk CHECK (...)`
— was correct, so this was sequencing, not misunderstanding.
 
[CREATE TABLE](https://www.postgresql.org/docs/17/sql-createtable.html)
 
---
 
### B2. Seven `NOT NULL` constraints given names
 
```sql
name text CONSTRAINT suppliers_name_nn NOT NULL
```
 
**Wrong because:** before PostgreSQL 18, `NOT NULL` is stored as
`pg_attribute.attnotnull`, a column property, not as a row in `pg_constraint`.
The name parses and is silently discarded. Verified on 17.6: the two tables produced
six catalog constraints, not thirteen, while all nine `attnotnull` flags were set
correctly.
 
**Rule:** do not name `NOT NULL` on PostgreSQL 17. Remove it with
`ALTER TABLE ... ALTER COLUMN ... DROP NOT NULL`, not `DROP CONSTRAINT`.
 
**Root cause:** the instruction said not to name them and gave the reason. Naming
them anyway was worth doing once as an experiment, but the migration file was left
describing seven constraints the database does not have — a repository that no longer
matches reality.
 
[5.5.2 Not-Null Constraints](https://www.postgresql.org/docs/17/ddl-constraints.html#DDL-CONSTRAINTS-NOT-NULL)
 
---
 
### B3. Explicit `NULL` left in a column definition
 
```sql
sort_order integer NULL
```
 
**Wrong because:** nullable is the default. The keyword exists only for compatibility
with other systems and carries no meaning. It had already been flagged and was left
in place on the next revision.
 
---
 
## C. Data types
 
### C1. `sort_order` declared `text` instead of `int`
 
**Wrong because:** the column exists to drive `ORDER BY`. Text sorts
lexicographically, so `'10'` falls between `'1'` and `'2'`. Eight units of measure
hide the bug; thirty expose it.
 
**Rule:** the type follows the meaning of the value, not what happens to fit.
 
**Repeat of E5 in Topic 1** — same category, different column.
 
---
 
### C2. Truncation assumed where `numeric` rounds
 
`2.555 * 10.01` into a `numeric(14,2)` column: answered `25.57`, correct is `25.58`.
 
**Wrong because:** multiplication of `numeric` is exact and the scales add — 3 + 2 = 5,
giving `25.57555` with no loss. Writing that into a column declared `numeric(14,2)`
casts it to scale 2 **by rounding**, not by dropping digits.
 
**Consequence worth remembering:** the rounding happens per row. Over a 40-line
estimate, `SUM(total)` can differ from `ROUND(SUM(quantity * unit_price), 2)`.
 
[8.1.2 Arbitrary Precision Numbers](https://www.postgresql.org/docs/17/datatype-numeric.html)
 
---
 
### C3. `double precision` — conclusion known, mechanism not
 
Answered: "floating point, may give an undefined number of decimal places."
 
**Wrong because:** that restates the conclusion. The mechanism is the base.
A fraction terminates in base B only if every prime factor of its denominator divides
B. `0.1` has denominator 10 = 2 × 5; the 5 does not divide 2, so in binary it is an
infinite repeating fraction and the 53-bit mantissa truncates it. `0.5` has
denominator 2 and is stored exactly.
 
Identical to 1/3 in decimal — the analogy was already written in `rules.md` 2.1 of
Topic 1 and was not connected to the question.
 
[8.1.3 Floating-Point Types](https://www.postgresql.org/docs/17/datatype-numeric.html#DATATYPE-FLOAT)
 
---
 
## D. NULL semantics
 
### D1. `CHECK` expected to reject or replace a NULL
 
Asked what happens on insert when `payment_terms_days` is omitted under
`CHECK (payment_terms_days >= 0)`, answered "it will write zero".
 
**Wrong because:** the row is accepted and the column stays NULL. `NULL >= 0`
evaluates to `NULL`, not `false`, and a check constraint rejects only on `false`.
Nothing writes a zero — there is no `DEFAULT` on the column, and a `CHECK` cannot
write values in the first place (see D3 of Topic 1: a column stores a value, it does
not fetch one).
 
**Rule:** `CHECK` never guards against missing values. `NOT NULL` does.
 
**Root cause:** reading the machine-translated documentation, which renders
`null value` as "нулевое значение". The translation destroys exactly the NULL/zero
distinction the passage is about. Read the English original.
 
[5.5.1 Check Constraints](https://www.postgresql.org/docs/17/ddl-constraints.html#DDL-CONSTRAINTS-CHECK-CONSTRAINTS)
 
---
 
### D2. `UNIQUE` + nullable — mechanism not reproduced
 
Answered: "because tax_id is unique for every supplier." That restates the word
UNIQUE and does not explain why it combines with nullable. The keyword was not named.
 
**Rule:** PostgreSQL treats NULLs as **distinct** from one another, so a `UNIQUE`
column accepts any number of them; uniqueness constrains only values that are
present. `UNIQUE NULLS NOT DISTINCT` (15+) inverts this to at most one NULL.
 
**Root cause:** the rule is written verbatim in `rules.md` 3.3 of Topic 1, keyword
included, and the file was open. Written down is not the same as available.
 
[5.5.3 Unique Constraints](https://www.postgresql.org/docs/17/ddl-constraints.html#DDL-CONSTRAINTS-UNIQUE-CONSTRAINTS)
 
---
 
## E. Defaults
 
### E1. `now()` assumed to be evaluated per row
 
Answered that three rows inserted a second apart get three different timestamps.
 
**Wrong because:** `now()` returns the start time of the **current transaction** and
does not move until it ends. All three rows get the same value, to the microsecond.
This is deliberate: one unit of work gets one consistent timestamp.
 
`clock_timestamp()` returns the real time at the moment of the call;
`statement_timestamp()` returns the start of the current statement.
 
**Consequence:** `created_at` cannot order the lines of one document, because a batch
insert writes them all in one transaction. That is what `line_no` is for — rule 1.1
of Topic 1, now confirmed by a mechanism rather than by assertion.
 
The first half of the answer was right: a `DEFAULT` expression is evaluated at insert
time, not at table creation.
 
[9.9.5 Current Date/Time](https://www.postgresql.org/docs/17/functions-datetime.html#FUNCTIONS-DATETIME-CURRENT)
 
---
 
## F. Process
 
### F1. Part of a listed instruction carried out, the rest dropped — four times
 
| Occasion | Asked | Done |
|---|---|---|
| Fixing the Topic 1 files | three broken separators, line numbers given | one |
| First `CREATE TABLE units` | code plus three questions | code only |
| Second attempt | remove `NULL`, answer three questions | neither |
| `suppliers` + `sites` | code plus three questions | code only |
 
**Why it matters here specifically:** a migration applied halfway leaves the database
in a state that exists in no version of the schema — not the old one, not the new one.
Unlike a half-edited document, it cannot be finished later by memory, because the
part that did apply is now invisible.
 
**Repeat of E6 in Topic 1** ("answering a different question than the one asked"),
in the form "doing part of what was listed". Four occurrences in a single session
is more than any single repeat across the whole of Topic 1.
 
---
 
## Recurring patterns to watch
 
1. **`ON DELETE` acts on children when a parent is deleted.** Direction first,
   criterion second.
2. **`CONSTRAINT name` before the constraint**, never after.
3. **`CHECK` passes `true` and `NULL`.** It is a gate, not a guard against absence
   and not a transformer.
4. **NULL is not zero**, in the documentation as much as in the data.
5. **`numeric` rounds when cast to its declared scale**, and does it per row.
6. **A default expression is evaluated per transaction, not per row**, when it is
   `now()`.
7. **Finish everything that was listed**, not the first item.
8. **Read the catalog after every migration** and compare it against the file.
9. **Run the experiment** instead of arguing about what the parser accepts.
10. **A rule written in a file is not yet a rule available in the head.** The gap
    closes on exercises, not on rewrites.
---
 
## Scorecard — Topic 2 (in progress)
 
| | Count |
|---|---|
| Foreign key semantics | 1 |
| Constraint syntax | 3 |
| Data types | 3 |
| NULL semantics | 2 |
| Defaults | 1 |
| Process | 1 |
| **Total so far** | **11** |
 
Repeats carried over from Topic 1: C1 (E5), D2 (rules 3.3 not reproduced),
F1 (E6, ×4).
 
Applied correctly without prompting: dependency levels across all nine tables,
including `supplier_materials` placed at the level of its **highest** parent;
cardinality asked in both directions on the `foremen` question, unprompted — the
single most repeated structural failure of Topic 1.
