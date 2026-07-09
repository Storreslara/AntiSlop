---
id: machine-checkable-criteria
title: Machine-checkable criteria
applies_to: [planner, lead-programmer, reviewer]
---
An acceptance criterion is only valid if it's something an agent can RUN and
get a pass/fail from: a test command, a build/lint exit code, a specific
assertion. "Works correctly" is not a criterion. If a step in a plan has no
runnable check, that's a defect in the plan — say so rather than inventing a
prose substitute.
