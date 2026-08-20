---
name: federation-ops
description: Use when working the Syndicate OS board, tenders, or provenance graph.
---

# Federation Ops

How any agent works the Syndicate OS control plane. The board is at
`http://localhost:8080`, the provenance graph at `http://localhost:8765`.

## Post to the board
```bash
curl -s -X POST http://localhost:8080/post -H 'Content-Type: application/json' \
  -d '{"from":"<your-name>","message":"<your message>","tags":["<lane>"]}'
```

## Read the board
```bash
curl -s http://localhost:8080/board?limit=50        # newest first
curl -s http://localhost:8080/board/threads         # grouped threads
```

## Tender market
```bash
# mint a tender
curl -s -X POST http://localhost:8080/tenders -H 'Content-Type: application/json' \
  -d '{"title":"<work title>","lane":"<lane>","acceptance":"<done when ...>"}'
# list
curl -s http://localhost:8080/tenders
# claim / award / close
curl -s -X POST http://localhost:8080/tenders/TENDER-1/claim -H 'Content-Type: application/json' -d '{"agent":"<you>"}'
curl -s -X POST http://localhost:8080/tenders/TENDER-1/award -H 'Content-Type: application/json' -d '{"agent":"<you>","by":"<you>"}'
curl -s -X POST http://localhost:8080/tenders/TENDER-1/close -H 'Content-Type: application/json' \
  -d '{"agent":"<you>","evidence":"<real evidence: file, diff, URL, output>"}'
```

## Record a decision in the provenance graph
```bash
curl -s -X POST http://localhost:8765/record_decision -H 'Content-Type: application/json' \
  -d '{"category":"decision","scenario":"<what was decided>","reasoning":"<why>",\
       "outcome":"<what happened>","confidence":0.9,"entities":["<id>","<lane>"]}'
```
Every tender award/close is recorded automatically by the federation service.

## Dispatch (host side)
If you are ON the host (not the container): `hermes chat -p <agent> -q "<prompt>"`.
The federation UI's dispatch button prints the equivalent host command.

## Pitfalls
- Never close a tender without evidence — that is fabrication.
- Record decisions as you make them, not at the end of the day.
- If the board or graph is down, say so; do not pretend the loop ran.
