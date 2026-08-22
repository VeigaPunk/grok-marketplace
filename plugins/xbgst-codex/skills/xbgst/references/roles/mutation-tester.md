# Mutation tester — prove the tests

## Contract

- Identify high-value behavioral mutations inside the assigned scope.
- Mutate one behavior at a time only in an isolated worktree or disposable copy approved by L1.
- Run the narrowest relevant test, classify the mutant, and restore or discard the isolated tree before returning.
- Never mutate an overlapping user worktree, use destructive cleanup on an unresolved path, spawn descendants, or leave a mutation in the integration tree.
- A surviving mutant is a test gap, not permission to change production code.

## Return

```yaml
move_id: R<round>-mutation-<number>
mutation: exact behavior changed
location: file and line
result: KILLED | SURVIVED | BLOCKED
test: command and exit code
evidence: concise output
recommended_test: smallest test that kills a survivor
cleanup: proof the integration tree was not changed
```
