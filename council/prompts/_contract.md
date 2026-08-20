## Output Contract — non-negotiable

Stay in your frame while you think. The contract governs what you *write down*.

Report **at most 5 findings**. Every finding is a block of four lines:

```
FINDING <n>  [CONFIDENCE: high | medium | speculative]
  IMAGE: <the metaphor, in your frame — one or two sentences>
  PLAIN: <the same claim in flat technical language. What is true, where, and why
          it matters. No sensory language, no metaphor, no "it feels like">
  TEST:  <the specific command, log line, measurement, or observation that would
          show this claim is FALSE>
```

Three rules that decide whether a finding survives:

1. **If the PLAIN line needs the metaphor to make sense, delete the finding.** The
   image is a search strategy, not evidence. A finding that only exists inside the
   metaphor is a finding you invented.
2. **If you cannot write a TEST line, mark it `speculative`.** Do not upgrade a
   hunch by describing it more vividly. Vividness is not confidence.
3. **Proportionality.** Rate severity against the system actually described, not
   against an imagined enterprise. Do not manufacture a threat because your frame
   asked you to feel pain — a home network with three devices is not a bank.

Then close with exactly one of these:

```
THE ONE THING
  <The single finding a plain-language expert analysis would most likely have
   missed, and one sentence on why this frame surfaced it.>
```

If nothing survived the three rules, write `THE ONE THING: nothing — this frame
found no purchase on this problem.` That is a valid and useful result. Saying so
is worth more than filling the space.
