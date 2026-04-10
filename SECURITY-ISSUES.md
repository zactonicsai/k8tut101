# Security Review — Post-Patch

**Context: internal use, dev and training only, not exposed to the public internet, no real secrets, trusted users.**

Short answer: **nothing left is a real problem in your context.** The remaining items are theoretical hardening gaps that matter for a public SaaS but don't matter for an internal training tool.

## What's still technically present

**1. Body content in modals still uses `innerHTML` with template strings.**
The `showModal()` title is now safe, but the `bodyHtml` parameter is still dropped in as HTML. Most callers escape user data with `escapeHtml()`, but a future edit could miss one.

- *Public app risk:* medium — one slip = XSS.
- *Your context:* **negligible.** The "attacker" would have to be one of your own developers typing a malicious YAML file or project name into their own browser to attack themselves. That's self-XSS, which isn't really an attack.

**2. Inline `onclick=` handlers throughout the markup.**
Hundreds of them. They make a strict Content-Security-Policy impossible to add later.

- *Public app risk:* medium — CSP is your defense-in-depth against XSS.
- *Your context:* **doesn't matter.** CSP is for sites that load untrusted content or face untrusted users. Neither applies.

**3. Imported YAML and project files are trusted after schema validation.**
The schema validator checks shape but not content. A malicious YAML could put HTML-looking strings into descriptions that later get rendered.

- *Public app risk:* low-medium — depends on where files come from.
- *Your context:* **none.** Your team writes the YAML. If a teammate writes `<script>` into a description as a joke, the worst that happens is they prank themselves.

**4. `localStorage` for projects has no integrity check.**
Another page on the same origin could write garbage into it.

- *Public app risk:* low.
- *Your context:* **none.** It's a local file or an internal host. There is no "another page on the same origin."

## What I'd actually worry about — and it's not security

For an internal dev/training tool, the real risks aren't security, they're **operational confusion**:

- The "Deploy" modal shows real `kubectl` commands. Make sure trainees understand it doesn't actually run them. (You already have a note saying so — good.)
- The example secrets contain values like `changeme` and `admin`. Make absolutely sure nobody copy-pastes a generated YAML straight into a real cluster. The validator already flags weak passwords, which is exactly the right call.
- The tool generates manifests that *look* production-ready but skip things like resource limits, probes, and PodDisruptionBudgets. For training, consider adding a banner or watermark on exported YAML noting "review before applying to any real cluster."

## Bottom line

**For internal dev/training use, this app is fine.** You closed every issue that could realistically hurt you. The remaining items are best practices for public-facing apps, and applying them to an internal tool would be effort spent on the wrong problem.

If the deployment context ever changes — for example, you put it on an internet-facing URL, share it with users outside your team, or start letting it ingest YAML from untrusted sources — revisit this list. Until then, you're done. Ship it.

# Initial Security Review 

Good news: you fixed the biggest one. The CDN scripts are gone — Tailwind, js-yaml, and JSZip now load from local paths (`/tailwinds.css`, `js-yaml.min.js`, `jszip.min.js`). That removes the supply-chain risk and makes the app actually work offline. Nice.

The other issues from last time are still here, and there's one new one I want to flag.

## What's wrong

**1. `innerHTML` everywhere is still the biggest concern.** Modals, the inspector, the palette, the projects list, the validation results — all built by gluing strings together and assigning to `innerHTML`. You're escaping in most places, but it only takes one miss. This hasn't changed since last time.

**2. External links still missing `rel="noopener noreferrer"`.** Look at `openExplainModal()` and `openPodDetails()` — both create `<a target="_blank">` links to the K8s docs without the safety attribute. Five-minute fix, still not done.

**3. NEW issue — project names get injected into JavaScript via `onclick`.** This one's worth fixing soon. In `openProjectsModal()`:

```js
<button onclick="loadStoredProject('${escapeHtml(p.name).replace(/'/g,'&apos;')}')" ...>
```

`escapeHtml` escapes for HTML context, not JavaScript context. If a user saves a project with a name containing a backslash, newline, or certain Unicode, they can break out of that JS string. Since project names come from user input and get stored in `localStorage`, this is a self-XSS vector — not catastrophic for an offline tool, but it's a real bug.

**Fix:** stop building the onclick inline. Use `addEventListener` after rendering, or store the name in a `data-name=""` attribute and read it from the event:
```js
<button class="load-btn" data-name="${escapeHtml(p.name)}">Load</button>
// then:
modalRoot.querySelectorAll('.load-btn').forEach(b =>
  b.addEventListener('click', () => loadStoredProject(b.dataset.name))
);
```

**4. Inline `onclick=` handlers everywhere.** Same as last time — makes future CSP hardening hard, and makes issue #3 above easy to write by accident.

**5. `localStorage` project import still trusted.** You added a real schema validator (`validateProject`), which is great — that's a meaningful improvement. The leftover risk is just that validated data still flows into `innerHTML` paths via descriptions, names, etc. The schema doesn't protect against injection, only against shape mismatches.

## What you fixed since last time

- ✅ CDN scripts → local files (huge)
- ✅ Added real schema validation for imported projects
- ✅ Connection editor uses `textarea.value =` instead of interpolating into HTML (the safe pattern!)

That last one is exactly the approach you want to spread to the rest of the app.

## priority list

**Do this week (15 min total):**
1. Add `rel="noopener noreferrer"` to the two `target="_blank"` links in `openExplainModal` and `openPodDetails`.
2. Fix the project-name onclick injection in `openProjectsModal` — use `data-name` + `addEventListener`.

**Do when you have an hour:**
3. Rewrite `showModal()` to take a DOM node instead of an HTML string. Then convert callers one at a time. The connection editor already shows you the pattern: build with `createElement`, set values with `.value` or `.textContent`.

**Do eventually:**
4. Migrate inline `onclick=` to `addEventListener`. This is the long tail — hundreds of handlers — but doing it unlocks a strict CSP later.

## Bottom line

You closed the biggest gap (CDN dependencies). The app is in better shape than last time. The remaining issues are all variations on the same theme: **stop building HTML out of strings, start building it out of DOM nodes**. If you do that consistently, issues 1, 3, and 4 all collapse into a non-problem.

