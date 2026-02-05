---
description: Generate cameo commit message
agent: build
subtask: true
---

Output Format:
```
<Module>: <subject>

[Model][Type][I#][M#][TM#]
Bug:
Cause:
Solution:
```

- Module: Fill in the name of the module related to this modification.
- Subject: Fill in the title of this commit.
- Model: Machine model name. If it's a Bug present across a series, you can also write the series project name.
- Type: Get the type based on the result of diff, can be Fix/Enhance/New/Refine.

If type is Fix, Bug/Cause/Solution must all be filled out correctly.
If type is not Fix, you can use * as a prefix instead Bug/Cause/Solution and write a detailed description.

Generate commit message based on staged changes:

!cd ${1:-.} && git diff --staged

When the command does not get diff result, do nothing.
