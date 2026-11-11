# Mistakes — Topic 6, subqueries and common table expressions
 
Kept in two parts, because the two move independently:
 
- **E — execution.** The mechanism was known; something else reached the answer.
  Includes incomplete answers: a question with several parts answered in part.
- **U — understanding.** The mechanism itself was wrong.
 
Records were kept during the session and written at the end of each major step.
This file covers steps 1 to 8, eighteen tasks (90 items).
 
---
 
## E — execution (12)
 
| # | What happened | Note |
|---|---|---|
| E1 | Task 1, item 2 — why the subquery returns one row and not 11 — the premise was given back: “the subquery outputs only one row and one column” | Closed with two narrowing questions: how many values `avg` gives from the 11 values of `delivery_items.total` (1), how many groups the rows form with no `GROUP BY` (1). Same shape as E20 of topic 5 |
| E2 | Task 1, item 5 — the number of rows of the changed subquery asked; the value given (“null, I suppose”) | Closed with one repeat of the question: 1. A quantity other than the one asked, as E5, E7 and E11 of topic 5 |
| E3 | Task 4, item 2 — the subquery written with the table name `supplier_materials` after the alias `sm` was set | The rule is in rules_04, 9.3. The student named `sm` when asked, and then closed the item |
| E4 | Task 4, item 2 — the test for NOT NULL written as `NOT NULL`, then as `NOT IS NULL` | “I don't remember”. The form `IS NULL` is in rules_04, section 10; the inverse is not written there. Closed after one question: where to put `NOT` inside `IS NULL` → `IS NOT NULL` |
| E5 | Task 4, item 4 — the ids left out of the result sent as “1,34,7” | A typing slip. Sent again as 1, 3, 4, 7 after the tutor pointed out that 34 is not a `materials.id` |
| E6 | Task 5, item 1 — the number of rows of the subquery for `suppliers.id` = 1 given as 1 (two: `deliveries.id` 1 and 5) | The ids asked for as a narrowing step came as “2”, then 1, 5. A quantity other than the one asked, as E2 |
| E7 | Task 6, item 5 — why `NOT IN` gives 0 rows and `NOT EXISTS` gives 10 — “because of NULL and the difference in how the subquery is evaluated” | General words, no values. Closed with the two values for `materials.id` = 5 (NULL and true), and then with a check of the claim “any NULL gives NULL” on row 1 (U6) |
| E8 | Task 7, item 3 — a reason asked for; the clause “WHERE s.id NOT IN” sent | Closed with one question: the number of NULL among the 11 values of `delivery_items.site_id` (0). The last answer was “true” typed with the Russian keyboard layout active (the letters come out as another word), accepted |
| E9 | Task 11, item 5 — why site 1 stands in one row with `t` and not in six — the premise was given back: “because delivery_items has 6 rows with delivery_items.site_id = 1” | Closed with one narrowing question: the clause of the subquery that makes the 6 rows one: GROUP BY. Same shape as E1 |
| E10 | Task 11, item 6 — the check from the other side: the sum of `delivered_total` against the sum of which column of which table — “t.delivered_total” (a column of the result itself), then “delivery_items” (no column) | Closed with two narrowing questions: the table the subquery sums, then the column: `delivery_items.total` |
| E11 | Task 13, item 2 — the question asked for the estimates (`estimates.id`) whose lines make `p.planned_total` of site 1; the answer was the line ids “1,2,3,4” | Accepted: the lines identify estimate 1. The key asked for was `estimates.id`; a different key from the one asked, as E5 and E6 |
| E12 | Task 18, item 2 — `false` typed with the Russian keyboard layout active | Accepted as `false`, as in E8 |
 
**Pattern.** E1, E2, E6 and E7 are the failures already in topic 5: the reason
restated as the premise (E1), a value or a list given instead of the quantity asked
(E2, E6), a result without the value and the reason (E7). E3 and E4 are in the one
subquery the student wrote; the first is a known rule, the second a form of syntax
he did not remember. All other items of tasks 3 to 8 were answered correctly on the
first send, among them the checks from the other side of tasks 5, 6 and 8 and the
number of rows of tasks 5 (7), 6 (10) and 8 (0 and 5).
 
---
 
## U — understanding (11)
 
| # | What was wrong | How it was closed |
|---|---|---|
| U1 | Task 4, item 1: `NOT IN` over a subquery with NULL — the number of rows given as 9 (right: 0); then false for `materials.id` = 2, then 3 rows, then `materials.id` 5, 8, 10 counted | After a long chain of narrowing questions the student asked to have the rule explained again. The tutor stated the three results of `NOT IN` (equal found, no equal and NULL present, no equal and no NULL); then 0 was answered. |
| U2 | Task 4: “id 5” given when asked what `materials.article_no` of material 5 is compared with — only with the rows of `supplier_materials` where `supplier_materials.material_id` = 5. “true!!! b500s-12 has id 5” | The query has no condition between `m.id` and `sm.material_id`. Closed with the number of rows of the subquery (13), of NULL among them (7), and the table of the 13 values written by the tutor. The student: “this is some nonsense” |
| U3 | Task 4: the case “found only unequal rows” named for `materials.id` 5 and for 8, with 7 NULL values among the 13 | Closed with: how many of the 13 are unequal to GRAV-1220 (6), and the 7 others are NULL → the case “no equal, NULL present”. The student had said “no” to “all 13 are unequal” just before |
| U4 | Task 5, item 3: the number of rows of `EXISTS` given as 9 and then “twice” for supplier 3 — the number of rows of `deliveries`, not one result row per row of `suppliers`. Later the student read the 2 rows of the subquery for supplier 1 as a contradiction with the 7 of the result | The tutor quoted the documentation (version 8): at most one output row for each row of the outer table. Then 7 was answered, and the check, supplier 8 left out |
| U5 | Task 6, item 2: `NOT EXISTS` for `materials.id` = 3 given as NULL | `EXISTS` over no rows is false, one question; `NOT` of false is true. The documentation says every form in that section gives true or false |
| U6 | Task 6, after item 5: “if at least one is NULL, then NULL at once” — then, for `materials.id` = 1 under `NOT IN`, the answer NULL and the case “no equal, NULL present” | An equal value, CEM-II-425, is among the 13: the result is false. NULL decides only when no equal value is found. Closed with three questions, the last one the three results written again by the tutor |
| U7 | Task 8, item 2: `NOT IN` for `suppliers.id` = 2 given as false (right: NULL) | The tutor said false needs an equal value; the student: none among B38123456 and NULL; so NULL. Same family as U1 and U6: NULL in the subquery |
| U8 | Task 8, item 1: `s2.id IN (1, 3)` read as “a range of IDs” | A list of two values, 1 and 3; 2 is not in it. The student then answered item 1 correctly. The rule of no ranges in rules and notes concerned the data given by the tutor, not the student's reading of SQL |
| U9 | Task 9, item 5: `> ANY` over the short subquery — the number of rows given as 8 (right: 9). The student: “but rows 10 and 11 are in the where conditions” — rows 10 and 11 were taken as left out because they stand in the `WHERE` of the subquery | The condition `di2.site_id = 2` filters `di2` only; the outer query reads all 11 rows of `di`. The tutor said so (a fact about the scope of the condition, not the answer), then one question: `ANY` for `delivery_items.id` = 11 → true. Then 9 and the check 9 + 2 = 11 |
| U10 | Task 18, item 3: “2 rows, or an error because of `m.id` = 10, I lean to the error” — the row failing `NOT EXISTS` taken as one the `INSERT` still receives | Closed with one question: does the `SELECT` pass the pair (7, 10) to the `INSERT` when `NOT EXISTS` is false — no. The wording of the item is T18 |
| U11 | Task 18, item 5: with `s.tax_id = NULL` the number of rows added given as 6 (right: 0) — the NULL tax ids of suppliers 3 and 6 times the 3 materials | Closed with two questions: the value of `s.tax_id = NULL` for `s.id` = 3 (NULL) and the number of rows `WHERE` keeps (0). The `= NULL` trap is the same family as U1, U6, U7 (NULL is not equal to anything) |
 
**Pattern.** U1, U2, U3, U6 and U7 are one gap: a NULL among the values of a
subquery under `NOT IN`. The student first took it as “false” or as “NULL decides at
once”, the left value NULL as a plain value, and the comparison of the left value
with all rows as a comparison with the rows of one material. By task 8 the three
results were applied correctly, with one more wrong first answer (U7). U4 is the
topic-5 gap of rows repeated by a join (U4, U6, U9 there) in a new place: `EXISTS`
gives one result per outer row. U5 is a regression of the same family: `NOT` over a
result that is true or false only. U9 is a new place for the scope of a condition: the
`WHERE` of a subquery taken for a filter of the outer rows. Tasks 9 (items 1 to 4, 6, 7)
and 10 (items 1 to 4) were otherwise right on the first send, and the `GROUP BY` /
`HAVING` query of task 10 was run by the tutor and equals the query given. U10 and U11
(task 18) are new places for old gaps: where a failing condition acts (before the
`INSERT`, not in it) and `= NULL` in `WHERE`. Tasks 13 to 17 had no other wrong
answer; U-type answers in step 8 came only in task 18.
 
---
 
## T — tutor (18)
 
| # | What was wrong |
|---|---|
| T1 | Section numbers of the documentation stated without a check against version 17: 4.2.11, 7.2.1.3, 7.2.1.5, 7.8.3, 7.8.4 from memory; 9.24 inferred from versions 15, 16 and 18. The pages of version 17 could not be fetched. Disclosed in the plan and in the text of the tasks; the anchor of the link in task 1 (`SQL-SCALAR-SUBQUERIES`) was not confirmed, a quotation seen in a mailing-list message gives `SQL-SYNTAX-SCALAR-SUBQUERIES`. The same for the sections of tasks 3 to 12: version 16 numbers given, 17 not seen |
| T2 | First message of the chat: question 3, whether the `seed.sql` in the repository has the two rows of `estimates`, was asked, although `context_06.md`, section 1, says the student attaches the file from the repository and the attached file had the rows. After “look at the screenshot” the tutor asked for another screenshot; the student had to say that the file sent was the repository one. Three messages |
| T3 | `notes_06.md`, first version of the section on how the tutoring should run (section 6 then, section 12 now): the rules of `notes_05.md`, section 13, were cut down to a shorter list instead of carried over whole. Left out: the `AS` label on every aggregate, the student answers in his own words, the data repeated on request, an item asks only what the task text says, seed formatting is the tutor's job, tasks name the file, table and line. The student asked whether the files match the structure of topic 5; the section was then rewritten in full |
| T4 | Task 4, “Short, by the text of the documentation”: only the condition of true (only unequal rows found) was given, with no definition of “unequal rows” and without the results false and NULL. The student could not apply it (“what does unequal rows of the subquery mean???”); the three results were stated only after a long chain of narrowing questions and his request. Same failure as T22 and T23 of topic 5 |
| T5 | Task 4, item 2 and its follow-up held two questions: the name allowed in the subquery and a reason from rules_04. Only the first was answered. Same shape as T9, T20 and T26 of topic 5 |
| T6 | Task 4, wrong-answer questions: “what is the `article_no` of material 5 compared with — only the rows with `material_id` = 5, or all 13” was leading and gave the wrong half a place to be chosen; the question about the inverse of `IS NULL` “by analogy” asked for a form that is not in rules_04 (“that is all that is written”) |
| T7 | Task 4 took about twenty questions for the item “how many rows”: the rule of narrowing questions only was applied three times after wrong answers on the same point. The student: “this is some nonsense”, “you are confusing me”, “every message costs tokens”. The rule from his request: after two wrong answers in a row show the rule of the documentation instead of a third narrowing question |
| T8 | Task 4: the second result of `NOT IN` was worded “no equal value, but a row with NULL is present” (NULL in the subquery), and the answer “3” was accepted for `materials.id` = 3, where the subquery has 6 values without NULL and NULL stands on the left. The wording and the accepted answer disagreed; the student found it. The rule was rewritten in full without numbers of cases |
| T9 | Task 5: `SELECT 1` used without a definition; the student: “what does SELECT 1 mean” |
| T10 | Task 6, check of the claim “any NULL gives NULL” on `materials.id` = 1: the question gave no data, the student: “I don't have the tables in front of me”. The rule that data is repeated on request was kept, but the data belonged in the question |
| T11 | Task 10, “Short, by the text of the documentation”: the statement that the alias of a subquery in `FROM` is optional from version 16 comes from descriptions of changes in search results, not from the page of version 17. Said in the task as “by the description of the changes”, the page was not opened. Later the version 17 page showed the alias is optional there, so the claim held for 17 |
| T12 | Task 9, “Short, by the text of the documentation”: the results of `ANY` and `ALL` given without the NULL row (no true and a NULL gives NULL for `ANY`; no false and a NULL gives NULL for `ALL`). The documentation of version 8 has it; the same kind of cut as T4. Found while writing the notes; the NULL rows were run on constant values afterwards |
| T13 | Task 12, item 3: “how many rows does the whole query return” could be read as the query of the task, a subquery, or the outer `SELECT` alone. The student answered with a pasted block, one `LEFT OUTER JOIN` with `p`, and “this one?”; the tutor guessed his meaning and asked a narrowing question about `sites`; the student then asked which query was meant and asked that an answer to another reading not be written as his error. Rewritten as “the query given in the task as a whole, from `SELECT s.id AS id` to `ORDER BY s.id;`”. Recorded here, not in E. Same failure as T3, T7, T11, T12 and T18 of topic 5 |
| T14 | Task 11, item 6: “the sum of `delivered_total` over the 6 rows must match the sum of which column of which table” did not say which tables count. The student: “do we consider only the tables of this task, or all tables and all previous tasks?”. Answered: only the tables of the task |
| T15 | Task 13: the task text had no documentation link, only the section name and number. The rule (one documentation link plus a summary) was kept in tasks 1 to 12. The student asked for the link in the task text and for the task to be repeated; the link was added and marked unopened |
| T16 | Task 13, item 2: no data in the message. The question named “the lines of `estimate_items` of which estimates” and the data held only which estimates have lines. The student: “give the table estimate_items”. Same as T10; the table was then sent |
| T17 | Task 17, item 5: the task did not say that `supplier_materials.supplier_id` is `NOT NULL`; the student answered “adds 1 row”, a reasonable answer without that fact. It was given only after two narrowing questions. Same as T10 and T16: data needed for the answer not in the message. Not recorded as the student's error 
| T18 | Task 18, item 3: “how many rows will be added, and it will not end with an error?” — the item stated the answer to half of its own question and asked for one number. The student gave two options and asked what to do; the item was rewritten as “rows (how many) or an error”. Recorded here, not in U10's cause |
 
**Pattern.** T1 is the kind already recorded as T17 and T19 of topic 5: a source
named with more certainty than was checked, disclosed in the text. T2 is a question
not checked against a file at hand (T2 and T4 of topic 5); T3 is the same shape, the
student found it. T4, T9 and T10 are about wording and data the student could not see
or could not use: a rule without its definition and without the other two results
(T4), a term not defined (T9, as T22 and T23 of topic 5), data not in the question
(T10). T5 repeats T9, T20 and T26 of topic 5: two questions in an item. T6 and T7
are the cost of the narrowing rule: a leading question, and a chain too long on one
point. T8 is an inconsistency between the rule as worded and an answer the tutor
accepted. T11 and T12 are of the T1 and T4 kind: a source not read to the end, and a
rule cut short in the summary. T13 and T14 are the old failure of a phrase or a scope
that can be read two ways (“the whole query”, which tables); the student pointed out
both, and in T13 asked that the ambiguity be counted against the tutor. T15 is a rule
of the file (a link in the task text) dropped; T16 repeats T10, data not in the
question, and the student again had to ask for it. T17 is the same third time, with a
constraint (`NOT NULL`) missing from the data; T18 is a question that stated half of
its own answer, the third kind of ambiguity after T13 and T14.
 
---
 
## Metric
 
To be given at the end of the topic, as in topic 5: execution discipline, complete
answers, understanding, recording discipline, out of 10 each.
