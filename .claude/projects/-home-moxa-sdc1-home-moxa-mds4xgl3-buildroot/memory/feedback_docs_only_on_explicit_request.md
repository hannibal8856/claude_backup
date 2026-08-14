---
name: docs-only-on-explicit-request
description: "During plan Q&A, do not proactively offer to update docx/pptx; treat questions as clarification, update only when user explicitly asks"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f799ca36-ae55-4954-a42d-21c79180a90b
---

After a planning artifact (docx/pptx/md) exists, technical Q&A from the user defaults to **clarification of the existing plan**, not a redesign request. Do not end Q&A responses with "要不要我把這個更新到 docx/pptx?" — wait for an explicit "加進去" / "更新文件" / "改成這樣" signal.

**Why:** 2026-06-08 — after a multi-round weekend Q&A (RESERVE1 phase usage, ConfigHandler trait, in-process vs HTTP URI, multi-varbind atomic SET, ureq vs reqwest, UDS②) where I closed each response with an offer to update the Plan D docx/pptx, the user said: "上個週末 (6/6~6/7) 的討論請先不要進入文件; 目前我覺得沒有要改動Plan C/D架構的誘因, 我只是想釐清plan裡面的技術細節". The Q&A was self-clarification, not a redesign brief.

**How to apply:**
- Answer technical questions cleanly and stop. No "要不要更新文件" tail.
- If the user's question implies a real architectural change (not just clarification), flag the implication explicitly but still don't auto-update — ask once whether they want it in the doc.
- If you've genuinely changed your earlier written stance during Q&A (e.g., admitting docx §6 was wrong), note it inline so the user knows the doc is now stale, but still don't update unless asked.
- Related: [[build-order]] for similar "wait for explicit go-ahead" pattern.
