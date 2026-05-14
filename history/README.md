# Agent Ledger - History Archive

This directory contains archived `agent-ledger` events that are older than 14 days.

## Why Archive?

To maintain the efficiency of the "hot" ledger for AI assistants. Massive ledgers consume excessive context window tokens and increase retrieval latency. 

## How to use

Assistants analyzing long-term trends or auditing past work must explicitly search this directory. The front-facing `WORK_IMPACT.html` and `CHANGES.html` should be updated to cross-reference these files.

This process is automated via a daily Windows Scheduled Task running `scripts/archive-old-ledger-entries.ps1`.
