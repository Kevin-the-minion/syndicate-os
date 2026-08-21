#!/usr/bin/env python3
"""token-watchdog.py — daily token/cost watchdog (silent watchdog pattern).

Silent when spend is under budget; emits a plain alert when over. Adapted
from the production fleet's watchdog (which runs daily at 22:00).

Usage:
  TOKEN_WATCHDOG_BUDGET_M=40 TOKEN_WATCHDOG_PRICE_PER_M=0.10 python3 token-watchdog.py
  # add to crontab: 0 22 * * * python3 <repo>/cost/token-watchdog.py
"""
import os
import re
import subprocess
import sys

BUDGET_M = float(os.environ.get("TOKEN_WATCHDOG_BUDGET_M", "40"))
PRICE_PER_M = float(os.environ.get("TOKEN_WATCHDOG_PRICE_PER_M", "0.10"))


def main() -> int:
    try:
        out = subprocess.run(
            ["hermes", "insights", "--days", "1"],
            capture_output=True, text=True, timeout=300,
        ).stdout
    except Exception as e:  # noqa: BLE001
        print(f"⚠ TOKEN WATCHDOG ERROR: insights failed: {e}")
        return 0

    total_m = None
    m = re.search(r"Total tokens:\s+([\d,]+)", out)
    if m:
        total_m = int(m.group(1).replace(",", "")) / 1_000_000

    if total_m is None:
        print("⚠ TOKEN WATCHDOG: could not parse `hermes insights --days 1` output")
        return 0

    cost = total_m * PRICE_PER_M
    if total_m > BUDGET_M:
        print(
            f"⚠ TOKEN BUDGET EXCEEDED: {total_m:.1f}M tokens "
            f"(budget {BUDGET_M:.0f}M) ≈ ${cost:.2f} — review cron jobs and driver loops."
        )
    else:
        print(f"token spend OK: {total_m:.1f}M tokens ≈ ${cost:.2f} (budget {BUDGET_M:.0f}M)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
