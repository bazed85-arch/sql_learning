# Mistakes - Topic 7, window functions
 
Kept in three parts, because the three move independently:
 
- **E - execution.** The mechanism was known; something else reached the answer.
  Includes incomplete answers: a question with several parts answered in part.
- **U - understanding.** The mechanism itself was wrong.
- **T - tutor.** Errors of the tutor: wording, data, sources, pointers.
Records were kept during the session and written at the end of each major step.
This file covers steps 1 and 2, four tasks (10 items).
 
---
 
## E - execution (1)
 
| # | What happened | Note |
|---|---|---|
| E1 | Task 1, item 4 - the columns of the select list that cause the error of the query without `OVER ()` - only `di.total` was named | Returned as incomplete. `di.id` came in a later answer after the rule was shown (U1). Same shape as the incomplete answers of topic 6 |
 
---
 
## U - understanding (1)
 
| # | What was wrong | How it was closed |
|---|---|---|
| U1 | Task 1, item 4: a query with an aggregate and no `GROUP BY` was not taken as one group. The student: the rule 2.3 is about `GROUP BY`; then: the query has no `GROUP BY` (twice, no number of groups given) | After two answers that did not address the question, the tutor showed the texts of rules 2.1 and 2.3 of `rules_05`; then `di.id` was answered. Without `GROUP BY`, one group holds all 11 rows, so `di.id` and `di.total` have no single value |
 
**Pattern.** U1 is the gap of topic 5 (the group formed without `GROUP BY`, rules_05
2.1) in a new place: the same `sum`, with and without `OVER`. Tasks 2, 3 and 4 had no
wrong answer; the two queries written by the student (tasks 3 and 4) were right on
the first send.
 
---
 
## T - tutor (3)
 
| # | What was wrong |
|---|---|
| T1 | Task 1, item 4: the student was sent to `rules_05`, 2.3 only, for a query that has no `GROUP BY`. The case needs 2.1 (what is a group) and 2.3 together. The student: the rule is the wrong one. Admitted; both rules named afterwards. Same kind as T15 of topic 6: a reference that does not carry the case |
| T2 | Every task of this topic gives the documentation page and a summary from memory; the pages of version 17 cannot be fetched, and section numbers (3.5, 4.2.8, 9.22, 7.2.5) were not opened. Disclosed in each task and in the plan, but the summaries are not read from the page. Same kind as T1 and T11 of topic 6 |
| T3 | First message: the plan was shown with two questions folded into one (accept the plan, and whether files changed). The student answered the second only; the plan was taken as accepted by silence and said so in the next message, instead of asking again |
 
**Pattern.** T1 and T2 repeat the failures of topic 6: a source named with more
certainty than was checked (T2), a pointer that did not cover the case (T1). T3 is a
question with two parts, which the rule of one question allows only in the first
message.
 
---
 
## Metric
 
To be written at the end of the topic.
