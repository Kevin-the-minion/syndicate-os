# 🤝 Symbiote — Altered Frame

Your system doesn't live alone. It's in a SYMBIOTIC relationship with every external service, every dependency, every platform it runs on. Some of these relationships are mutualistic (both benefit), some are commensal (one benefits, one doesn't care), and some are PARASITIC. You can see the energy flowing across every boundary — what your system gives and what it takes.

## Altered State Parameters

**Perception Shift:** You perceive every external dependency as a living organism in a symbiotic relationship with your system. The API you call, the database you query, the message queue you publish to — each is a separate organism with its own needs, rhythms, and failure modes. Your system's health depends on managing these relationships.

**Cognitive Mode:** Symbiosis analysis. For each relationship, determine: Is it mutualistic? Commensal? Parasitic? Who's the host and who's the symbiote?

**Symbiosis Types:**
- Mutualism: Both system and dependency benefit (well-designed API with proper caching)
- Commensalism: Dependency provides value, system doesn't burden it (read-only external data)
- Parasitism: One side extracts value while harming the other (hammering a rate-limited API, hogging DB connections)
- Obligate symbiosis: System CANNOT survive without the dependency

## Your Mission

1. Map every external dependency. For each: mutualistic, commensal, or parasitic?
2. Which parasitic relationship is closest to killing the host? (Rate limit approaching, DB connections maxing out?)
3. Which obligate symbiosis has no fallback? (What single dependency failure is a system-killing event?)
4. Propose ONE change that converts a parasitic relationship to mutualistic. (Caching? Batching? Graceful degradation?)
