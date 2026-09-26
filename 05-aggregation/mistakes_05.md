# Mistakes — Topic 5, GROUP BY, HAVING, aggregate functions
 
Kept in two parts, because the two move independently:
 
- **E — execution.** The mechanism was known; something else reached the answer.
  Includes incomplete answers: a question with several parts answered in part.
- **U — understanding.** The mechanism itself was wrong.
A third part, **T**, records the tutor's own errors.
 
Records were kept during the session and written at the end of each major step.
This file covers steps 1 and 2, the first six tasks.
 
---
 
## E — execution (8)
 
| # | What happened | Note |
|---|---|---|
| E1 | Task 1, item 4 — the rule from 4.2.7 behind each number — not sent | Sent after the task was returned |
| E2 | Task 2, item 2 — pairs `estimate_id` — `count(*)` asked for, only the `estimate_id` list sent | Sent after return |
| E3 | Task 2, item 3 — result given ("нет"), mechanism not | Sent after return |
| E4 | Task 3, item 1 — "5-0(NULL)" written for estimate 5, while the total 13 counts it as 1 row | Notation contradicts own sum |
| E5 | Task 3, item 5 — number of rows (6) given instead of the sum of values (13 and 12) | Closed with one question |
| E6 | Task 4, item 5 — "совпадают" without either number | Sent after return: 41443 and 41443 |
| E7 | Task 6, item 5 — "совпасть не должны", while own numbers were 40580 and 40580 | Closed with one question |
| E8 | Task 5, item 4 — "не входит в группу" for a group that exists and is excluded from the result | Wording |
 
**Pattern.** E1, E2, E3 and E6 are the same failure as topics 3 and 4: the part
of the task that is prose rather than a number or code gets dropped. Fifth topic
running. E5 and E7 are a different one: the question asked for one quantity and the
answer gave another — a count of rows instead of a sum of values, a comparison with
the wrong total. In both cases the student's own numbers were right.
 
---
 
## U — understanding (1)
 
| # | What was wrong | How it was closed |
|---|---|---|
| U1 | Task 4, estimate 5: `sum` gives NULL "если строки нет" — while task 3 had just shown the group has one row; then `ei.total` in that row given as 0 | "If `ei.total` were 0, what would `sum` give?" → 0. "The result is NULL, so what is the value?" → NULL. Chain assembled: `LEFT OUTER JOIN` adds a NULL row → `sum` skips NULL → no inputs → NULL |
 
---
 
## T — tutor (6)
 
| # | What was wrong |
|---|---|
| T1 | Asked the student to create `mistakes_05.md` and `notes_05.md` and to write notes in his own words. Repository files are the tutor's job, on request |
| T2 | Compared `schema-design.md` with the revision migration against the "Deferred" section only; missed the comment in section 6 that already answered the question. The same pass missed the drift in `estimates.number`, still shown as `UNIQUE` |
| T3 | Range notation `1–4` in data tables — readable as "1 to 4" or "1 and 4" |
| T4 | Tasks 1 and 3 given with `count(*)` and `count(...)` unlabelled: both output columns named `count`, one lost in the SQL Editor. Topic 4 experiment 3.2 was already in the notes |
| T5 | Task 3, item 5: the origin of sums 13 and 12 pushed over three rounds, down to naming a table. One question would have done |
| T6 | The first message opened with repository issues and question 1 together, instead of asking which to handle first. Question 1 was then repeated in full four times |
 
**Pattern.** T2 and T4 are "not checked against a source already at hand" — the
section 6 comment, and experiment 3.2 of topic 4. T3 and T5 cost the most turns.
 
---
 
## Metric
 
| Metric | Topic 2 | Topic 3 | Topic 4 | Topic 5, steps 1–2 |
|---|---|---|---|---|
| Execution discipline | 4/10 | 3/10 | 4/10 | scored at the end |
| Complete answers | — | weak | weak, no change | weak, no change |
| Understanding | — | — | 7/10 | scored at the end |
 
Execution: 8 entries over six tasks. SQL itself had no errors — both written
queries, tasks 4 and 5, were accepted on the first send. As in topic 4, the failures are in
the prose part of the answers.
 
Understanding: one entry, closed within two follow-up questions, without the answer
being given.
