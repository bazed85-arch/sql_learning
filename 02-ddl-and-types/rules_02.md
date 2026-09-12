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

**1.5 A repository describes the database only once it has been used to rebuild it.**

Drop the schema, replay the migrations in timestamp order, apply `seed.sql`, compare.
Until that has been done, the claim that the migrations reproduce the database is a
hope.

Done at the end of this topic: eleven tables, 58 constraints, identical result. Worth
repeating whenever a migration is added by hand rather than generated.
 
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

**2.6 A missing comma turns a table constraint into a column constraint.**

```sql
created_at timestamptz NOT NULL DEFAULT now()
CONSTRAINT t_pk PRIMARY KEY (a, b)          -- no comma above
```

The parser sees no boundary and reads the constraint as part of the `created_at`
definition — i.e. as a column constraint, where `PRIMARY KEY` takes no column list
because it applies to exactly one column. Syntax error, class 42.

The same text with a comma is a two-column primary key on the table. One character
decides which of the two grammars applies.

**2.7 `ON DELETE` lives inside the `REFERENCES` clause, not beside it.**

REFERENCES reftable [ ( refcolumn ) ] [ MATCH ... ]
[ ON DELETE action ] [ ON UPDATE action ]

They are one constraint. Inserting `NOT NULL` between them closes the foreign key
definition and leaves `ON DELETE` stranded — syntax error, class 42.

`NOT NULL` is a separate column constraint. Put it before `CONSTRAINT ... REFERENCES`
or after the whole clause. Order between constraints is free; the integrity of each
one is not.

**2.8 Constraint names must stay predictable, including the long ones.**

`estimate_items_estimate_id_line_no_uq`, not `estimate_items_uq`. A convention is only
worth having while a name can be derived from the column list without looking. The
short form also leaves no room for a second `UNIQUE` on the same table.

## 2A. Composite primary key and foreign keys on the same columns

**2A.1 A composite PK and the FKs on its columns guarantee different things, and
neither substitutes for the other.**

In a junction table, `supplier_id` and `material_id` are covered by both a composite
`PRIMARY KEY` and a `FOREIGN KEY` each.

- The **PK** guarantees the *pair* does not repeat, and that both columns are
  `NOT NULL`. It does not check that the numbers correspond to anything: the pair
  `(999, 888)` is unique and, to the PK, faultless.
- Each **FK** guarantees its own value exists in the parent table. It knows nothing
  about the pair: inserting `(1, 5)` twice does not concern it.

One blocks duplicates, the other blocks references into nothing. Remove either and
the matching class of garbage appears.

**2A.2 Two foreign keys into the same table are ordinary; the column names carry the
meaning.**

`unit_conversions` references `units` twice. `unit_id` cannot appear twice, so the
columns must be named for their roles: `from_unit_id`, `to_unit_id`. Named
`unit_id_1` and `unit_id_2` the schema would behave identically and be unreadable.

This shape — a table related to itself through an intermediate table — is common:
employee and manager, category and parent category, part and assembly.
 
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

**5.4 `ON DELETE` follows from the *type of relationship*, not from the parent's
independence alone.**

The earlier formulation — "does the parent exist in its own right" — is necessary but
not sufficient. An estimate is a perfectly independent entity, and its lines still
cascade.

| Relationship | Meaning | Action |
|---|---|---|
| **Reference** | the child points at an independently existing object: a unit, a material, a supplier | `RESTRICT` |
| **Composition** | the child is *part of* the parent, does not exist outside it, and takes its identity from it | `CASCADE` |

Working test: **does the child row have an identity of its own outside the parent?**

Estimate line number 3 — the third line of *what*? The question has no answer without
the estimate, and `line_no` is unique only within `estimate_id`. Composition →
`CASCADE`.

A material with `unit_id = 2` stays that material whatever the unit is.
Reference → `RESTRICT`.

Applying one action uniformly across a table is the mistake, in either direction.

**5.5 `NOT NULL` does not stop an empty string. Use `length(trim(col)) > 0`.**

| Value | `col <> ''` | `length(col) > 0` | `length(trim(col)) > 0` |
|---|---|---|---|
| `'cement'` | passes | passes | passes |
| `''` | caught | caught | caught |
| `' '` | **passes** | **passes** | caught |
| `'   '` | **passes** | **passes** | caught |

The first two are the same expression written twice. Only the third catches the case
that actually arrives: a FlutterFlow form where the user pressed space. That row is
invisible in a list, breaks nothing, and cannot be found by `IS NULL`.

`trim` removes spaces only — a tab still passes. Good enough: the target is real user
input, not a crafted value.

**On a nullable column the same expression needs no `OR col IS NULL`.**
`length(trim(NULL)) > 0` evaluates to `NULL`, and `CHECK` rejects only on `false`.
So `NULL` passes and `''` is caught — exactly the wanted behaviour. This is the one
place where the `CHECK`/`NULL` rule (5.1) helps instead of surprising.

**5.6 `CHECK` works as long as everything it compares is in the current row.**

That is the whole boundary, and it cuts both ways.

Works: `CHECK (from_unit_id <> to_unit_id)`, `CHECK (planned_end_date >= start_date)`,
`CHECK (line_no > 0)`. Two columns of one row, or one column against a constant.

Does not work, and needs a trigger instead:

| Wanted | Why `CHECK` cannot |
|---|---|
| the inverse factor equals `1 / factor` | needs two rows of the same table |
| `to_unit_id` equals the material's `unit_id` | needs two tables |

A constraint that cannot be expressed in the schema is the worst kind, because in
practice it will not exist. That is an argument for designing the possibility of
divergence out of the model rather than policing it.
 
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

 **6.5 `date` vs `timestamptz` is decided by what the value describes, not by how it
is entered.**

`date` — a calendar fact. Goods were received on 5 September; that stays 5 September
regardless of who reads the row or from where. There is no moment within the day and
none is needed.

`timestamptz` — a point in time. An absolute instant, meant to be ordered against
other instants. Stored as UTC and rendered in the reader's time zone.

Manual vs automatic entry is not the criterion: `estimate_date` is typed by hand and
is a `date`; `now()` can be written into a `date` column without complaint.

Cost of swapping them, on this project's own geography: the office is at UTC+0, a
supplier at UTC+1. Store a delivery date as `timestamptz` and 1 March entered in
Madrid at midnight reads as 28 February 23:00 here — the document date changed
because of a time zone, while the paper note still says 1 March.

The reverse swap is no better: `created_at` as `date` destroys ordering within the
day, which is the only reason that column exists.

**6.6 `::type` is a cast. `CAST(expr AS type)` is the same thing, spelled longer.**

Three levels of permission, in `pg_cast.castcontext`:

| Code | Name | Performed |
|---|---|---|
| `i` | implicit | automatically, anywhere |
| `a` | assignment | automatically, **only when storing into a column** |
| `e` | explicit | only when written out with `::` or `CAST` |

`int → numeric` is implicit — nothing is lost. `numeric → int` is assignment only:
the fractional part disappears, and PostgreSQL will not do that silently in the middle
of an arbitrary expression, but will do it when writing into an `int` column.

Consequence: `year_no int GENERATED ALWAYS AS (EXTRACT(YEAR FROM d)) STORED` compiles
without complaint — the cast happens by itself. Write `::int` anyway, for the reason
that `STORED` is written out: a silent conversion is behaviour the next reader has to
deduce.

**6.7 `EXTRACT` returns `numeric`, not `int`.**

One return type covers every field, including `seconds` with a fractional part.
`date_part()` is the same function with a different spelling and returns
`double precision` — worse here, for the reasons in 6.1.

[10.4 Value Storage](https://www.postgresql.org/docs/17/typeconv-query.html) ·
[9.9 Date/Time Functions](https://www.postgresql.org/docs/17/functions-datetime.html)

**6.8 A factor and a measured quantity need different precision.**

Money is counted to the cent because a cent is the smallest indivisible unit. A factor
has no such unit — it is a multiplier, and its error is multiplied by the entire
quantity it is applied to.

`m² → sheet` for a 2500×1200 plasterboard is 0.3333333333: a repeating fraction with no
exact value. At `numeric(14,2)` it becomes 0.33, and across 300 sheets that is a
9-sheet discrepancy created purely by rounding. `numeric(20,10)` leaves an error below
any physical measurement involved.

---

## 6A. Generated columns

**6A.1 `STORED` is mandatory on PostgreSQL 17.**

`VIRTUAL` arrived in 18 and is the default there. Write the keyword explicitly in
either case: behaviour that depends on the server version must not depend on silence
in the DDL.

**6A.2 A generated column cannot be written to, and the error is not class 23.**

The value is a function of other columns of the same row. Allowing a write would
permit a row where `total <> quantity * unit_price` — destroying the only guarantee
the construct provides. Like identity columns, this is a question of *permission to
write*, not of data consistency, so the rejection comes from class 42.

**6A.3 It recomputes on UPDATE, not only on INSERT.**

Any update touching an operand re-evaluates the expression. The value never
"freezes" — which is exactly why a frozen price (`unit_price`) must be an ordinary
column and not generated from anywhere.

**6A.4 The expression is stored in `pg_attrdef`, alongside `DEFAULT` expressions.**

Only `pg_attribute.attgenerated` distinguishes them: `s` for STORED, empty for an
ordinary column. Reading `pg_attrdef` alone cannot tell a default from a generated
column.

[5.4 Generated Columns](https://www.postgresql.org/docs/17/ddl-generated-columns.html)

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

## 7A. ALTER TABLE

**7A.1 `ALTER TABLE` runs against data that already exists — that is the whole
difference from `CREATE TABLE`.**

`ADD CONSTRAINT` validates every existing row. One violating row aborts the change
entirely: the constraint is not added at all. There is no "applies to new rows only"
and no partial result. A constraint added by `ALTER TABLE` binds the past as well as
the future.

`ADD CONSTRAINT ... NOT VALID` is the escape hatch: the constraint is recorded without
checking existing rows and enforced only on rows inserted or updated afterwards.
`VALIDATE CONSTRAINT` checks the backlog later. Built for the real case — a million
rows, some of them dirty, a week of cleaning ahead, and new writes that must be
protected today.

`pg_constraint.convalidated` is the only way to tell afterwards whether the old rows
were ever checked.

**7A.2 Changes that must apply together go in one command.**

`ALTER TABLE t ADD ..., DROP ..., ADD ...` is a single unit: if any action fails,
none of them takes effect. Written as separate statements, each commits on its own,
and a failure in the third leaves the table in a state described by no version of the
schema.

Concrete case from this topic: dropping the old `UNIQUE` and adding the wider one as
two statements can leave the table with *neither* — duplicate delivery notes pass
silently, and nobody notices until stock stops reconciling.

Actions inside one command execute left to right, so a later action can use a column
added by an earlier one. Ordering and rollback boundaries are separate concerns —
sequencing is not a reason to split.

*(The full solution is `BEGIN` / `COMMIT` around the migration file. Supabase CLI
applies a migration inside a transaction; the dashboard SQL Editor does not.)*

**7A.3 A constraint cannot be modified — only dropped and recreated.**

`ALTER TABLE ... ALTER CONSTRAINT` exists but only changes `DEFERRABLE`. The column
list of a constraint never changes.

**7A.4 Constraints accumulate; they do not supersede one another.**

A row must satisfy all of them at once, so the stricter always wins. "Widening" a
constraint by adding a looser one is impossible — the old one has to go.

[5.7 Modifying Tables](https://www.postgresql.org/docs/17/ddl-alter.html) ·
[ALTER TABLE](https://www.postgresql.org/docs/17/sql-altertable.html)

**7A.5 `ADD COLUMN ... NOT NULL DEFAULT x` fills the existing rows too.**

The default is not only for future inserts — at `ADD COLUMN` time it populates every
row already in the table. It has to: otherwise those rows would violate the `NOT NULL`
the moment the column appears.

Practical effect: forty estimates created before revisions existed become revision 1
of themselves, with no data fixing required.

**Without a `DEFAULT`, the same command fails** on a non-empty table — `23502`. There
is nowhere for the value to come from. `NOT NULL` with no default can only be added to
an empty table, or in two steps: add nullable, populate, then constrain.

*Aside on rewriting, which is a different question:* since PostgreSQL 11 a
**non-volatile** default (a constant like `1`) does not rewrite the table file —
the value is supplied on read. A volatile default such as `now()` does rewrite, since
each row gets its own value. This concerns speed on large tables, not the content.

**7A.6 `DEFAULT` is a convenience; `CHECK` is a guarantee. Neither replaces the
other.**

`revision int NOT NULL DEFAULT 1` does nothing when a value *is* supplied:
`INSERT ... (revision) VALUES (0)` stores a zero, and `-5` stores a minus five.
A default applies only in the absence of a value.

Same shape as `NOT NULL` failing to stop `''`: the constraint protects a different
thing from the one being assumed.

---
 
## 7B. DROP TABLE

**7B.1 Without `CASCADE`, tables drop in the reverse order of creation.**

A table cannot be dropped while a foreign key points at it. Order matters: level 2
first, level 0 last — referencing tables before referenced ones. The dependency levels
built for creation are read bottom-up here.

The refusal is `2BP01`, `dependent_objects_still_exist` — class 2B, not 23. Nothing is
wrong with the data; PostgreSQL is declining to remove an object that others depend on.

**7B.2 `DROP TABLE ... CASCADE` removes dependent *objects*, not dependent tables.**

`DROP TABLE units CASCADE` drops the foreign keys that referenced `units`. The tables
holding them — `materials`, `estimate_items`, `delivery_items`, `unit_conversions` —
survive, along with their data, minus the referential integrity they used to have.

That is what makes it more dangerous than it looks: after a mistaken `CASCADE` the
database still works and quietly starts accumulating references to nothing.

Not every dependent object behaves like a foreign key. A view built on the table is
dropped entirely, because a view cannot exist without what it selects from.

**7B.3 Two different `CASCADE`s.**

| | Fires on | Removes |
|---|---|---|
| `ON DELETE CASCADE` | a parent **row** is deleted | the child rows |
| `DROP TABLE ... CASCADE` | a **table** is dropped | objects depending on it — constraints, views |

The first is about data, the second about structure. The shared keyword is historical.

Note also what `ON DELETE CASCADE` does *not* do: it never deletes the parent row.
That deletion is the command you issued; the cascade only follows.

**7B.4 Everything owned by the table goes with it.**

Indexes and constraints belong to the table and cannot exist without it. A sequence is
different — one created by `CREATE SEQUENCE` is a free-standing object and survives
anything. But an identity column's sequence is recorded as `owned by table.column`,
and that ownership is what makes it drop alongside.

So the answer depends on the ownership record, not on the object type. Confirmed by
dropping all eleven tables: zero orphaned sequences, zero orphaned constraints.

[DROP TABLE](https://www.postgresql.org/docs/17/sql-droptable.html)
 
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

**8.3 The catalogue stores a parse tree, not your text.**

Four canonicalisations seen in this topic alone:

| Written | Stored |
|---|---|
| `IN ('a','b')` | `= ANY (ARRAY['a','b'])` |
| `price >= 0` | `price >= (0)::numeric` |
| `trim(name)` | `TRIM(BOTH FROM name)` |
| `EXTRACT(YEAR FROM d)::int` | `(EXTRACT(year FROM d))::integer` |

Comparing a migration against the catalogue character by character is meaningless.
Compare meaning.
 
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
