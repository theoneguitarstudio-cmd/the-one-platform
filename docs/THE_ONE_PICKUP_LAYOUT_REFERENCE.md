# Pickup-style Layout / Interaction Reference

Status: implementation specification, based on OWNER local recordings reviewed 2026-09-08.
Reference only; no source brand, copy, media, icons, fonts or curriculum copied.

## Recording evidence and implementable specification

Reviewed chronological frames every 5 seconds over recording A (162.13s, 1918×906) and B (37.25s, 1918×982), with enlarged inspection of A 50s and B 0/10/30s. Local frames stay in ignored artifacts/pickup-reference; no uploads. Timing is approximate; no mobile viewport appears.

| Screen / timestamps | Observed structure, hierarchy and scrolling | The One implementation target |
| --- | --- | --- |
| A public 0–40s | Slim floating/sticky centered header (~5–7% of visible height); logo left, limited nav, login + primary CTA right. Centered large headline/CTA/media; large alternating sections, not dense UI. Content roughly central 70–80% of viewport. | White header ~72px; centered hero at max 900px, 44–64px headline, one primary value/CTA; original visual below; 64–96px section rhythm. Keep own brand and warm subtle backgrounds. |
| A dashboard 50–75s | Fixed global left nav ~12% width, dark full-height surface, content takes remainder. Welcome then compact in-progress row, learning plan, wider content collections. Active nav has lighter surface. Scroll changes content while left rail stays. | 184px desktop global nav; content max 1200px, 32–48px padding. Continue Learning first, then practice/feedback/private lesson/course information; no fabricated catalog or KPI. |
| A navigation 80–140s | Primary and secondary groups; current page highlight; expandable categories, account bottom. Content tabs change current section. | Today/My Learning/Feedback/Practice/Private Lessons/Profile. Separate local Mock lesson search, Support details, Account link; no commerce/admin navigation. |
| B course/path 0–35s | Global nav collapses to icon rail (~3%); second course outline ~25%; content remainder. Course title, stage accordion, overview, numbered lesson rows with current strip and completion/locks. Outline retains position while lesson content scrolls. | 68px global rail + 270px outline + flexible content. Course → Stage 1 → Module 1 → existing lesson fixtures. Independent outline scroll, stage accordion, visible selected and locked state. No Grade/Day domain. |
| B video 0–5s | Small breadcrumb/title above horizontal lesson/exercise/jam segments; large 16:9 video dominates center. Stable bottom overview/completed/next control row. | Central max 1100px, 24–32px spacing, 28–34px title, 16:9 original placeholder. Five local segments: lesson/material/exercises/jam. Sticky bottom previous/temporary practice marker/next. |
| B text 10–20s | Text/diagrams appear below player in same central scroll region; narrower readable text measure. Outline and bottom controls remain. Not evidence of a separate text route. | Same workspace also offers Text material segment: original Chinese heading, paragraphs, bullets, practice notes. No copied diagrams. Content changes without changing course context. |
| B exercises 25–35s | Segment changes video/notation area and lower action text while outline stays. | Original exercise instructions and silent/static rhythm display; no fake playable video/audio. Segment previous/next and subsequent lesson navigation work locally. |
| Mobile | No mobile recording; responsive behavior is not evidenced. | Under 760px: global drawer; course outline accordion; one content column. Scrollable tabs and compact sticky action row, no horizontal page overflow. |

## Visual and data boundary

Public light/airy; core student learning dark/focused. Shared type, spacing, rounded geometry and original music mark. Dark palette uses The One deep charcoal, slate, soft blue and restrained warm accent, not reference purple. White/gray text maintains contrast; keyboard focus is visible.
Map remains six canonical Stage outcomes with current stage, milestone goal and module/node detail. Course outline is local navigation, never replaces the global Stage journey.
All newly displayed content/marked practice is synthetic and session-local. Watching is not completion, no server save, no entitlement or VERIFIED progress. Production connections/SQL/writes stay zero.
No new backend, migration, membership decision or Epic renumbering. Existing non-Mock guards and server student authorization remain.

## Acceptance

Local lint/types/Mock tests/build; desktop/mobile video and text, tabs, previous/next, temporary mark/reload clearing, locked route, outline scroll. Online same checks after explicit Preview-only deploy. /__preview-meta and bottom Preview SHA must identify the deployed source; dirty local builds clearly marked.

## Local validation result

51 unit tests, lint, typecheck, Mock build, 38 HTTP checks PASS. 36 browser checks PASS across 1440/1024/390: video/text, exercise 1/2/jam, previous/next, temporary mark/reload, locked route, keyboard segments, reset content scroll, independent outline scroll, mobile global/outline navigation and local search. No page errors or horizontal overflow. Strict network run keeps WARN for blocked antivirus injection; no Supabase calls. Original media/frames are excluded in .gitignore and never staged.
