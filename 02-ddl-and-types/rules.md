# Rules — DDL, Data Types & Constraints
 
**Block 1 · Topic 2 — DDL, data types, integrity constraints**
 
Reference sheet. Read before writing any migration.
 
Rules only — no history of who got what wrong. Each rule states the **mechanism**,
not just the conclusion, because a conclusion without its mechanism does not transfer
to a new problem.
 
Target: PostgreSQL 17 / Supabase.
 
Status: partial. Covers `CREATE TABLE`, types, constraint syntax, identity, defaults.
`ON DELETE` actions, generated columns and `ALTER TABLE` are added as the topic
progresses — an empty section is honest, an invented rule is not.
 
---
 
## 1. Creating tables
 
**1.1 Tables are created in dependency order, not in any order.**
 
A `FOREIGN KEY` declared inside `CREATE TABLE` requires the referenced table to
already exist. Sort the schema into levels: level 0 has no foreign keys at all,
level N references only levels below N. A table sits at one level higher than its
highest parent, not its lowest.
 
```
level 0  units, suppliers, sites
level 1  materials, estimates, deliveries
level 2  supplier_materials, estimate_items, delivery_items
```
 
The levels give a **partial** order. Within a level the order is free; across levels
it is not. Keep the migration file in level order and do not reshuffle it later
"to read better" — the only ordering that matters here is technical.
 
**1.2 A cycle is the one case that cannot be ordered.**
 
If a table cannot be placed at any level, the schema contains a circular reference.
Escape hatch: create all tables without the foreign keys, then add them with
`ALTER TABLE ... ADD CONSTRAINT`. Needing this is a signal to re-examine the design,
not a routine technique.
 
**1.3 The migration file is the source, the SQL Editor is not.**
 
Text typed into the Supabase SQL Editor is not stored and not versioned. Write the
SQL in `supabase/migrations/`, paste it into the editor to run it. Anything applied
to the database and not present in the repository is undocumented state.
 
**1.4 Migration file names must match the Supabase CLI convention from the start.**
 
`supabase/migrations/<timestamp>_<name>.sql`, where the timestamp is 14 digits,
`YYYYMMDDHHmmss`, UTC. Flat directory only — the CLI does not read subfolders.
Local files are matched against `supabase_migrations.schema_migrations` on the server
by timestamp alone, so a `001_` style prefix does not fit the scheme and mixing the
two formats breaks `db push`.
 
[CREATE TABLE](https://www.postgresql.org/docs/17/sql-createtable.html) ·
[5.1 Table Basics](https://www.postgresql.org/docs/17/ddl-basics.html)
 
---
 
## 2. Constraint syntax
 
**2.1 `CONSTRAINT name` comes BEFORE the constraint it names.**
 
The grammar for a column constraint is:
 
```
[ CONSTRAINT constraint_name ] { NOT NULL | NULL | CHECK (expr) | DEFAULT expr |
  GENERATED ... AS IDENTITY | UNIQUE ... | PRIMARY KEY ... | REFERENCES ... }
```
 
The name attaches to whatever follows it. Written the other way round,
`PRIMARY KEY CONSTRAINT units_pk GENERATED ALWAYS AS IDENTITY` produces an
**anonymous** primary key and hands the name to the identity clause, where it is
discarded. Both forms parse; only one does what was intended.
 
**2.2 Name every constraint explicitly.**
 
Three reasons, all practical:
 
- The constraint name is what appears in the error message — in the log, in the
  PostgREST response, on the user's screen. PostgreSQL does not know what the
  expression means; the name is the only human-readable part.
- `ALTER TABLE ... DROP CONSTRAINT` takes a name. An auto-generated one has to be
  looked up in the catalog first.
- Auto-generated names are an implementation detail and are not a stable contract
  across versions.
Convention: `<table>_<columns>_<type>`, where type is `pk`, `uq`, `fk`, `chk`.
`units_code_chk`, `deliveries_supplier_id_delivery_note_number_uq`.
 
**2.3 `NOT NULL` is not a named constraint before PostgreSQL 18.**
 
It is stored as `pg_attribute.attnotnull`, a column property, not as a row in
`pg_constraint`. `CONSTRAINT x NOT NULL` parses and the name is **silently
discarded** — verified empirically on 17.6. Consequences: do not name it, and remove
it with `ALTER TABLE ... ALTER COLUMN ... DROP NOT NULL`, never `DROP CONSTRAINT`.
 
*(PostgreSQL 18 changes this and makes not-null constraints catalog objects.
Do not carry the 17 behaviour forward without checking.)*
 
**2.4 A constraint over more than one column must use table-level syntax.**
 
Column-level syntax can only see its own column. Composite primary keys
(`PRIMARY KEY (supplier_id, material_id)`), multi-column uniqueness
(`UNIQUE (estimate_id, line_no)`) and any `CHECK` comparing two columns
(`CHECK (planned_end_date >= start_date)`) go in the table constraint list at the end.
 
**2.5 `IN (...)` is stored as `= ANY (ARRAY[...])`.**
 
Not a distortion — `IN` over a literal list is syntactic sugar. The rewritten form is
what appears in the catalog and in error messages, so learn to read it.
 
[5.5 Constraints](https://www.postgresql.org/docs/17/ddl-constraints.html)
 
---
 
## 3. Identity columns
 
**3.1 `GENERATED ALWAYS AS IDENTITY` by default. `BY DEFAULT` only for imports.**
 
`ALWAYS` rejects a user-supplied value on `INSERT` unless `OVERRIDING SYSTEM VALUE`
is written explicitly, and allows only `SET id = DEFAULT` on `UPDATE`.
`BY DEFAULT` accepts any supplied value silently.
 
Mechanism that decides it: a manual insert **does not advance the sequence**.
Load rows with ids 1–500 by hand under `BY DEFAULT`, and the sequence is still at 1;
the first automatic insert collides with the primary key. The failure surfaces later,
in production, not during the import.
 
Legitimate uses of `BY DEFAULT`: migrating data from a legacy system where existing
ids are referenced elsewhere, and restoring a dump. Both one-off, both imports.
Application code never assigns a surrogate id.
 
**3.2 `PRIMARY KEY` gives uniqueness, not a value.**
 
`id bigint PRIMARY KEY` with no identity clause is an ordinary column. The DDL
succeeds and the table looks correct; the first `INSERT` that omits `id` fails on the
implicit `NOT NULL`. Errors of this shape live in the data, not in the schema.
 
**3.3 An identity column is `NOT NULL` but not unique by itself.**
 
The sequence can be reset and values can be inserted manually. Uniqueness comes from
`PRIMARY KEY` or `UNIQUE`, never from the identity clause.
 
[5.3 Identity Columns](https://www.postgresql.org/docs/17/ddl-identity-columns.html)
 
---
 
## 4. Defaults
 
**4.1 A `DEFAULT` expression is evaluated at insert time, not at table creation.**
 
The table stores the expression text, not a result. This is what makes
`DEFAULT now()` meaningful at all.
 
**4.2 `now()` returns the start of the current transaction.**
 
It does not move while the transaction runs. Forty rows inserted by one transaction
carry an identical `created_at`, down to the microsecond — deliberately, so that one
unit of work has one consistent timestamp.
 
| Function | Returns |
|---|---|
| `now()`, `current_timestamp` | start of the current transaction |
| `statement_timestamp()` | start of the current statement |
| `clock_timestamp()` | actual time at the moment of the call |
 
Consequence: `created_at` cannot order the lines of one document. That is what
`line_no` is for — rule 1.1 of Topic 1, confirmed empirically.
 
[5.2 Default Values](https://www.postgresql.org/docs/17/ddl-default.html) ·
[9.9.5 Current Date/Time](https://www.postgresql.org/docs/17/functions-datetime.html#FUNCTIONS-DATETIME-CURRENT)
 
---
 
## 5. CHECK and NULL
 
**5.1 `CHECK` accepts a row when the expression is `true` OR `null`. It rejects only
on `false`.**
 
`CHECK (payment_terms_days >= 0)` on a nullable column does not block NULLs:
`NULL >= 0` evaluates to `NULL`, not to `false`, because a comparison against an
unknown is unknown. The row is accepted and the column stays NULL.
 
A `CHECK` never defends against missing values. That is the job of `NOT NULL`, and
the two are complementary, not overlapping.
 
**5.2 `CHECK` is a gate, not a transformer.**
 
It evaluates a boolean over the row and either lets it through or does not. It cannot
write a value back. `CHECK (code = lower(trim(code)))` **rejects** `'M3'`; it does not
convert it to `'m3'`. Normalisation is the application's job, or a `BEFORE INSERT`
trigger.
 
**5.3 `UNIQUE` and nullable combine deliberately.**
 
PostgreSQL treats NULLs as **distinct** from each other, so a `UNIQUE` column accepts
any number of them. Uniqueness applies only to values that are present: three
suppliers with no tax id all insert; two suppliers with the same tax id do not.
 
`UNIQUE NULLS NOT DISTINCT` (PostgreSQL 15+) inverts this — at most one NULL.
 
[5.5.1 Check Constraints](https://www.postgresql.org/docs/17/ddl-constraints.html#DDL-CONSTRAINTS-CHECK-CONSTRAINTS) ·
[5.5.3 Unique Constraints](https://www.postgresql.org/docs/17/ddl-constraints.html#DDL-CONSTRAINTS-UNIQUE-CONSTRAINTS)
 
---
 
## 6. Types in practice
 
**6.1 `double precision` cannot store `0.1`, and the reason is the base, not rounding.**
 
A fraction terminates in base B if and only if every prime factor of its denominator
divides B. `0.1` has denominator 10 = 2 × 5. In base 2 the factor 5 does not divide,
so `0.1` is an infinite repeating binary fraction, `0.00011001100110011…`. The
53-bit mantissa truncates it, and what is stored is the nearest representable binary
value. Hence `0.1 + 0.2 = 0.30000000000000004`.
 
Same mechanism as 1/3 in decimal — only the awkward denominators differ.
`0.5` is stored exactly: denominator 2, factor 2 divides base 2.
 
`numeric` stores decimal digits and computes on them, so any value with a finite
decimal representation is exact. The cost is speed. On money that is the right trade.
 
**6.2 Multiplying `numeric`: scales add, then the declared scale rounds.**
 
`numeric(14,3) * numeric(14,2)` produces an exact result with scale 5.
Writing it into a `numeric(14,2)` column rounds to 2 — rounds, does not truncate.
 
```
2.555 * 10.01 = 25.57555 → stored as 25.58
```
 
Rounding happens **per row**. Across a 40-line document, `SUM(total)` may differ from
`ROUND(SUM(quantity * unit_price), 2)` by a few cents. Which of the two is correct is
an accounting decision, not a database one.
 
**6.3 A type is chosen by the meaning of the value, not by what fits.**
 
`sort_order` as `text` sorts lexicographically: `'10'` lands between `'1'` and `'2'`.
Eight rows hide it, thirty expose it.
 
**6.4 Do not write `NULL` in a column definition.**
 
Nullable is the default. The keyword is accepted for compatibility with other
systems and adds nothing.
 
[8.1.2 Arbitrary Precision Numbers](https://www.postgresql.org/docs/17/datatype-numeric.html) ·
[8.1.3 Floating-Point Types](https://www.postgresql.org/docs/17/datatype-numeric.html#DATATYPE-FLOAT)
 
---
 
## 7. What the database creates on its own
 
**7.1 `PRIMARY KEY` and `UNIQUE` create a unique index automatically.**
 
Uniqueness cannot be enforced without one — the alternative is a full table scan per
insert. `FOREIGN KEY` creates **no** index on the referencing column. That asymmetry
is deliberate and is a separate design decision.
 
**7.2 An identity column creates a sequence owned by that column.**
 
`units_id_seq owned by units.id`. Ownership means it is dropped together with the
table. Not a free-standing object to manage separately.
 
---
 
## 8. Verifying the result
 
**8.1 Check the catalog, not the Table Editor.**
 
The dashboard shows a simplified view. The system catalog is what the database knows
about itself, and it settles any disagreement between the schema document and reality.
 
Columns:
 
```sql
select attnum, attname, format_type(atttypid, atttypmod) as type,
       attnotnull, attidentity
from pg_attribute
where attrelid = 'public.units'::regclass
  and attnum > 0 and not attisdropped
order by attnum;
```
 
Constraints:
 
```sql
select conname, contype, pg_get_constraintdef(oid)
from pg_constraint
where conrelid = 'public.units'::regclass;
```
 
`'public.units'::regclass` casts a table name to its OID. `attnum > 0` excludes system
columns, which have negative numbers. `not attisdropped` excludes dropped columns,
which remain in the catalog as holes.
 
| `attidentity` | | `contype` | |
|---|---|---|---|
| `a` | ALWAYS | `p` | primary key |
| `d` | BY DEFAULT | `u` | unique |
| `''` | not an identity | `c` | check |
| | | `f` | foreign key |
 
[Chapter 53 System Catalogs](https://www.postgresql.org/docs/17/catalogs.html)
 
**8.2 Verify the migration file against the catalog before committing.**
 
A file describing thirteen constraints when the database holds six is a defect, even
though both "work". The repository is only useful while it matches reality.
 
---
 
## 9. Documentation
 
**9.1 Read the English original.**
 
The machine-translated documentation renders `null value` as "нулевое значение",
which is the exact confusion between NULL and zero that rule 1.4 of Topic 1 exists to
prevent. The translation destroys the distinction it is being consulted about.
 
**9.2 Chapter 5 explains, Part VI Reference defines.**
 
"Why is it like this" → Chapter 5. "Is this form allowed" → the syntax diagram in the
reference page. Only the grammar is exhaustive.
 
**9.3 Pin the version in every link.**
 
`/docs/current/` follows the latest release and silently changes meaning under you.
This project runs 17. Write `/docs/17/`.
 
**9.4 An experiment settles a question faster than an argument.**
 
Whether a name attaches to `NOT NULL` took one `CREATE TABLE` and one catalog query
to answer. Rule 9.3 of Topic 1 said verify the construct exists; running it is the
strongest form of verifying.
 
---
 
## Checklist before running a migration
 
- [ ] Tables ordered by dependency level
- [ ] Every constraint named, `NOT NULL` excepted
- [ ] `CONSTRAINT name` written before the constraint, not after
- [ ] Multi-column constraints in table-level syntax
- [ ] Every surrogate key `GENERATED ALWAYS AS IDENTITY`
- [ ] Every `numeric` carries precision and scale
- [ ] Every nullable column checked: is a `CHECK` doing work a `NOT NULL` should do?
- [ ] No bare `NULL` keyword in any column definition
- [ ] File name is `<14-digit timestamp>_<name>.sql` under `supabase/migrations/`
- [ ] Catalog read after running, compared against the file
