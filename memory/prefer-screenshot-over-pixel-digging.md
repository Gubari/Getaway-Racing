---
name: prefer-screenshot-over-pixel-digging
description: For visual/UI issues, ask the user for a screenshot instead of long automated inspection
metadata:
  type: feedback
---

When a UI/visual problem is reported, just ask the user for a screenshot rather than spending many turns running the app, capturing/cropping/zooming screenshots, and sampling pixels.

**Why:** The user got impatient watching me run multi-step screenshot+pixel-alpha investigations to diagnose a missing button border. A single screenshot from them resolves it instantly.

**How to apply:** For "why does X look wrong" UI questions, ask for (or accept) a screenshot first. Only fall back to automated capture if they can't provide one.
