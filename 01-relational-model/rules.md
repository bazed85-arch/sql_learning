# Rules — Relational Model & Schema Design
 
Reference sheet. Read before designing any schema.
 
Rules only — no history of who got what wrong. Each rule states the **mechanism**,
not just the conclusion, because a conclusion without its mechanism does not transfer
to a new problem.
 
Target: PostgreSQL 17 / Supabase.
 
---
 
## 1. The relational model
 
**1.1 A table is a set of rows, and a set has no order.**
`SELECT` without `ORDER BY` may return rows in any order, and that order may change
between runs. If order matters, it must be a column (`line_no`, `created_at`,
`sort_order`). "Row 12" does not exist; "the row where `line_no = 12`" does.
 
**1.2 Rows are identified by data, not by position.**
There is no cursor, no row number, no first row. There is `WHERE id = 47`.
 
**1.3 Columns are atomic.**
One column holds one value. A list in a cell is a text file pretending to be a value.
 
**1.4 NULL means unknown or not applicable — not zero, not empty string.**
`NULL = NULL` is not true; it evaluates to NULL. Two NULLs are not equal.
`sites.actual_end_date IS NULL` means "not finished yet" — a meaningful answer,
not missing data.
 
---
 
## 2. Data types
 
**2.1 Money is `numeric`. Never `double precision`, never `money`.**
 
Mechanism: `double precision` is **binary** floating point. Decimal fractions such as
0.1 are not exactly representable in binary, the same way 1/3 is not representable in
decimal. `0.1 + 0.2` yields `0.30000000000000004`. Over a 47-line document the error
accumulates and the total stops matching the sum of the lines.
`numeric` stores decimal digits and computes exactly.
 
Do not use `money`: its output format depends on the `lc_monetary` locale and it does
not record which currency it holds.
 
[8.1.2 Arbitrary Precision Numbers](https://www.postgresql.org/docs/17/datatype-numeric.html) ·
[8.2 Monetary Types](https://www.postgresql.org/docs/17/datatype-money.html)
 
**2.2 Always state precision and scale.**
Money → `numeric(14,2)`. Quantity → `numeric(14,3)`.
Bare `numeric` is arbitrary precision and lets `8.4000000001` in.
 
**2.3 `date` for a calendar day, `timestamptz` for a moment.**
 
Ask: **is this a calendar fact, or an instant in time?**
 
| Value | Type | Reason |
|---|---|---|
| `delivery_date` | `date` | Goods were received on that day, in any timezone |
| `estimate_date` | `date` | The document is dated that day |
| `created_at` | `timestamptz` | An instant — when the row entered the system |
 
Never plain `timestamp`: it stores a wall-clock reading with no record of which zone
it came from, and that information is lost permanently.
 
[8.5 Date/Time Types](https://www.postgresql.org/docs/17/datatype-datetime.html)
 
**2.4 `text`, not `varchar(n)`.**
No performance difference in PostgreSQL, and `varchar(n)` costs a length check.
If a limit is genuinely needed, use a `CHECK` — it can be altered later without
rewriting the column type.
*(PostgreSQL-specific. Do not carry this habit to SQL Server or Oracle.)*
 
[8.3 Character Types](https://www.postgresql.org/docs/17/datatype-character.html)
 
**2.5 Identifiers that are never arithmetic are `text`.**
Phone numbers (`+34`, spaces, extensions), tax ids (letters, leading zeros),
article numbers, postal codes. A number type silently destroys leading zeros.
 
**2.6 Fixed value sets: `text` + `CHECK`, not `enum`.**
Adding an enum value is easy; removing or renaming one is not, and migrations make it
worse. A `CHECK` is trivially altered.
*(This is a trade-off, not settled fact — competent engineers disagree.)*
 
Values inside a `CHECK` must be lowercase English identifiers. They end up in
application code and API responses. UI labels are translated in the interface layer.
 
---
 
## 3. Keys
 
**3.1 `PRIMARY KEY` and `UNIQUE` are different things.**
 
| | `UNIQUE` | `PRIMARY KEY` |
|---|---|---|
| Allows NULL | yes, any number | no |
| Per table | any number | at most one |
| Default FK target | no | yes |
 
Preventing duplicates is what they have in common, not what distinguishes them.
 
**3.2 Surrogate primary key on every table; natural keys as `UNIQUE`.**
 
Mechanism: natural keys change. A supplier is re-registered with a new tax number, a
manufacturer renumbers its catalogue. A changing PK propagates into every foreign key
in the database.
 
`bigint generated always as identity` by default. `uuid` where the id appears in a URL
or is exposed to a customer — sequential ids leak row counts and can be enumerated.
 
[5.3 Identity Columns](https://www.postgresql.org/docs/17/ddl-identity-columns.html)
 
**3.3 `UNIQUE` and nullable combine deliberately.**
 
Mechanism: PostgreSQL treats NULLs as **distinct** by default, so a `UNIQUE` column
accepts any number of them. Article numbers are unique when present; rows without one
are unrestricted.
 
`UNIQUE NULLS NOT DISTINCT` (PostgreSQL 15+) inverts this — at most one NULL.
 
[5.5.3 Unique Constraints](https://www.postgresql.org/docs/17/ddl-constraints.html#DDL-CONSTRAINTS-UNIQUE-CONSTRAINTS)
 
**3.4 A composite PK is valid only when the combination is unique by the nature of
the data.**
 
Test it on two example rows before accepting it.
 
- `supplier_materials (supplier_id, material_id)` — correct: one supplier gives one
  price for one material.
- `delivery_items (delivery_id, site_id)` — wrong: one truck delivers cement *and*
  rebar to the same site. The second row is a duplicate key.
Surface similarity between two "junction-looking" tables is not evidence.
 
**3.5 Uniqueness is usually scoped to the parent, not global.**
 
Line 1 exists in every document. Note 1024 exists at every supplier.
 
`UNIQUE (estimate_id, line_no)` · `UNIQUE (delivery_id, line_no)` ·
`UNIQUE (supplier_id, delivery_note_number)`
 
A global `UNIQUE` on `line_no` would permit exactly one line number 1 in the entire
database.
 
**3.6 Keep the database id and the human-readable number separate.**
`id` — for the database, never displayed, never changes.
`number` — for people, printed on the document, may be edited.
 
---
 
## 4. Relationships
 
**4.1 Ask the cardinality question in BOTH directions, in writing, before placing
any FK.**
 
- Can one A have many B?
- Can one B have many A?
Yes / No → one-to-many.
**Yes / Yes → many-to-many.**
 
One direction alone does not distinguish the two cases. This is the single most
common source of structural error.
 
**4.2 In one-to-many, the FK sits on the "many" side. Only there.**
 
One site has many estimates → `estimates.site_id`.
The parent carries no reference back to its children.
 
An FK in both directions is a **circular reference**: neither row can be inserted
first, and the design silently limits the parent to one child.
 
**4.3 Many-to-many requires a junction table — but it may already exist.**
 
A document-lines table often resolves a many-to-many by its own structure.
`delivery_items` carries three roles at once: child of the delivery note, reference
to a material, and resolution of the many-to-many between deliveries and sites.
 
**4.4 A junction table is an entity, not plumbing.**
It attracts attributes: price, lead time, minimum order quantity, the supplier's own
article number. Once it has those, it is a price list, not a link.
 
**4.5 A foreign key stores an identifier, not a role.**
"Latest", "current", "active" are results of a query
(`WHERE status = 'approved'`), never something a column can mean. An FK is one
specific number, written once, that never moves.
 
**4.6 Check every new FK against the assumptions already recorded.**
If it contradicts one, either the FK is wrong or the assumption needs revising —
explicitly.
 
---
 
## 5. Constraints
 
**5.1 `CHECK` sees only the row being inserted or updated.**
 
Mechanism: the expression evaluates over that row's own columns. It has no access to
other tables — physically, not by policy. `CHECK (material_id = materials.id)` is not
valid SQL.
 
Cross-table rules are enforced by foreign keys, or by triggers.
 
[5.5.1 Check Constraints](https://www.postgresql.org/docs/17/ddl-constraints.html#DDL-CONSTRAINTS-CHECK-CONSTRAINTS)
 
**5.2 `CASCADE` follows document structure. `RESTRICT` protects independent entities.**
 
The question is **not** "does this row make sense without its parent" — it is
**"does the parent exist in its own right?"**
 
| FK | Behaviour | Why |
|---|---|---|
| `estimate_items.estimate_id` | `CASCADE` | Delete the estimate, its lines go with it |
| `delivery_items.delivery_id` | `CASCADE` | Same — lines of a document |
| `delivery_items.site_id` | `RESTRICT` | A site is independent. CASCADE would erase years of purchase history |
| `*.material_id` | `RESTRICT` | A material exists in the catalogue on its own |
| `*.supplier_id` | `RESTRICT` | Never silently delete supply history |
 
Better than deleting independent entities at all: `is_active boolean` and hide them.
 
[5.5.5 Foreign Keys](https://www.postgresql.org/docs/17/ddl-constraints.html#DDL-CONSTRAINTS-FK)
 
**5.3 Put business rules in the database.**
`CHECK (quantity > 0)`, `CHECK (unit_price >= 0)`, `CHECK (lead_time_days >= 0)`.
Application code gets bypassed — by Edge Functions, by the dashboard, by direct SQL.
The constraint holds in all three.
 
Ask whether **zero** is legitimate, not only whether negatives are. A line with
quantity zero is not a line.
 
**5.4 Nullability: can the row exist meaningfully without this value at insert time?**
 
| `NOT NULL` | nullable |
|---|---|
| The row is meaningless without it | The value may be unknown or not applicable |
| Closed reference list, filled once | Business attribute, filled by a user |
| `units.code`, `materials.name`, `deliveries.supplier_id` | `materials.article_no`, `suppliers.tax_id`, `sites.actual_end_date` |
 
`NOT NULL` on an optional business attribute blocks real work: a material cannot be
created until someone invents an article number for it.
 
---
 
## 6. Generated columns
 
**6.1 A generation expression may reference only other columns of the same row.**
 
No subqueries, no other tables, no aggregates, no other generated columns.
The expression must be immutable.
 
`total = quantity * unit_price` works on `estimate_items` because both operands are in
the row. A document total is a **sum across many rows** — an aggregate — and aggregates
are never generated columns. Compute with `SUM()` in a query or expose through a view.
 
[5.4 Generated Columns](https://www.postgresql.org/docs/17/ddl-generated-columns.html)
 
**6.2 PostgreSQL 12–17: `STORED` only. `VIRTUAL` arrived in 18 and is the default there.**
Always write the keyword explicitly — omitting it is version-dependent behaviour.
 
**6.3 A column stores a value; it does not fetch one.**
Nothing pulls a default from another table automatically. Copying a value at insert
time is the **application's** job. Reading it live is a **join**. There is no third option.
 
Input values cannot be generated at all: `quantity` on a delivery line is what a
storekeeper counted. The database does not know what was on the truck.
 
---
 
## 7. Normalization
 
**7.1 1NF — atomic values, no repeating groups.**
 
Violations: a list in one cell; `material_1, material_2, material_3`.
 
**Repeating data grows downward as rows, never sideways as columns.**
 
This applies to repetition over *time* (price history → rows with validity dates) and
to repetition within a *document* (estimate lines → a child table). Same mechanism.
 
Test: **how many of these can one record have?**
Exactly one → a column. Many, count unknown in advance → a separate table.
 
A repeating group in columns also makes foreign keys impossible: 47 columns cannot
meaningfully reference one catalogue table.
 
**7.2 2NF — no partial dependency on a composite key.**
 
Applies only where the PK is composite. Every non-key column must depend on the
**whole** key.
 
`estimate_items (estimate_id, material_id)` holding `material_name` violates it —
the name depends on half the key, so it is duplicated across every estimate using
that material.
 
**7.3 3NF — no transitive dependency.**
 
No non-key column may depend on another non-key column.
 
**Everything depends on the key, the whole key, and nothing but the key.**
 
`deliveries` holding `supplier_name`: the name depends on `supplier_id`, which is
itself non-key. The supplier renames itself; you fix 12 rows and miss 400, and
"how much did we buy from them" returns two different answers.
 
**7.4 The historical-value exception.**
 
A stored price looks like a transitive dependency — it is reachable through
`material_id` → `supplier_materials`. It is not a violation.
 
**The test: does this value describe the referenced ENTITY, or the EVENT?**
 
| Value | Describes | Action |
|---|---|---|
| Supplier's phone number | the supplier | normalize away |
| Price agreed on an estimate line | that estimate | **store a frozen copy** |
| Price paid on a delivery line | that delivery | **store a frozen copy** |
| Unit written on a delivery note | that delivery | **store it** |
 
If the price were a live reference, an April price increase would silently rewrite a
March estimate the client already signed.
 
**7.5 A derived value is not stored unless there is a specific reason.**
 
| Value | Where |
|---|---|
| Planned quantity | `estimate_items.quantity` |
| Actual quantity | `delivery_items.quantity` |
| Outstanding balance | nowhere — computed |
 
"Fully / partially delivered" is the result of comparing sums, not a fact about the
document. A `status` column is still justified for the **state of the document**
(received, received with issues, rejected).
 
**7.6 Where a value is USED is not where it is DEFINED.**
 
Tax rate applies to every line, but one estimate has one rate → it belongs on the
header. Currency likewise.
 
A value moves to the lines only when it **actually differs** between lines. And when
it does, it becomes an FK to a reference table, not free text.
 
**7.7 3NF is the working target.**
Below it: update anomalies. Above it (BCNF, 4NF, 5NF): rarely relevant.
Denormalize deliberately, with a stated reason — never by accident.
 
---
 
## 8. Design procedure
 
1. Write the business process in plain sentences.
2. Underline the nouns → candidate tables.
3. Underline the verbs → candidate relationships.
4. **For each pair, ask the cardinality question in both directions** (rule 4.1).
5. List the participants of every event table: **who, to whom, when, what**.
   An event table without its participants cannot answer the question it exists for.
6. Then attributes, then types, then constraints.
Step 4 done in one direction is where most schemas break.
Step 5 omitted is how a deliveries table ends up with no supplier.
 
---
 
## 9. Specification discipline
 
**9.1 Every column line has four parts: name, type, constraints, one-line justification.**
Anything less cannot be implemented and cannot be reviewed.
 
Why it matters beyond pedantry: an ambiguous schema handed to an LLM produces
plausible-looking wrong migrations, and the error is invisible unless the right answer
was already decided.
 
**9.2 If the justification does not come out in one sentence, it is an open question,
not a decision.**
"I can't explain why, but I think it should be like this" is the signal that a form was
copied rather than designed.
 
A marked gap costs nothing. An unverified construct costs a lot.
 
**9.3 Verify the construct exists before writing it.**
`CHECK` across tables, `VIRTUAL` on PostgreSQL 17, an FK to a non-unique column —
all invalid, all easy to write.
 
**9.4 Record assumptions in the schema document.**
A recorded assumption is part of the design. An unrecorded one is a future bug.
 
---
 
## 10. Naming
 
| Element | Rule | Example |
|---|---|---|
| Tables | `snake_case`, plural | `estimate_items` |
| Primary key | always `id` | `estimates.id` |
| Foreign key | `<referenced_table_singular>_id`, **singular** | `material_id`, not `materials_id` |
| Columns | `snake_case`, singular | `unit_price` |
| Booleans | `is_` / `has_` prefix | `is_active` |
| Timestamps | `_at` suffix | `created_at` |
| Dates | `_date` / `_from` / `_to` | `delivery_date`, `valid_from` |
 
**10.1 `snake_case` is not a preference.**
PostgreSQL folds unquoted identifiers to lower case. `supplierMaterials` silently
becomes `suppliermaterials` unless quoted everywhere, forever.
 
[4.1.1 Identifiers and Key Words](https://www.postgresql.org/docs/17/sql-syntax-lexical.html)
 
**10.2 The table is already the context.**
`materials.name`, not `materials.material_name`.
 
**10.3 Same name, different meaning is a design smell.**
`units.code` (the unit itself, `NOT NULL`) versus `materials.code` (an optional article
number) — rename the second to `article_no`.
 
**10.4 On Supabase, a column name is an API field name.**
PostgREST generates the API from the schema. Renaming a column is a breaking API
change, not an internal edit. Get names right before the first migration.
 
---
 
## Checklist before declaring a schema done
 
- [ ] Cardinality asked in both directions for every pair, in writing
- [ ] No FK pointing back from a parent to its children
- [ ] Every event table lists who / to whom / when / what
- [ ] Every composite PK tested on two example rows
- [ ] Every FK has a stated `ON DELETE` behaviour, chosen per rule 5.2
- [ ] Every `numeric` has precision and scale
- [ ] Every date column checked: calendar fact or instant?
- [ ] Every stored value checked: entity or event?
- [ ] No derived value stored without a stated reason
- [ ] Every column has a one-sentence justification
- [ ] Assumptions written down
- [ ] Names final — they become the API
