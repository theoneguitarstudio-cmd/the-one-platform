<!-- BEGIN:nextjs-agent-rules -->

# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->

# The One 樂玩吉他 2.0 project rules

- Keep the application a modular monolith. Domain and authorization logic belongs in `src/modules`, not UI components.
- Preserve role boundaries for Student, Teacher, Admin, and Super Admin. Every privileged operation must be re-authorized on the server and protected by database policy.
- Never expose secrets, service-role credentials, production personal data, database dumps, or private backups to the browser or Git.
- Core brand colors are yellow `#FFD70A`, white `#FFFFFF`, and black `#171717`. Use yellow as an accent rather than a full-page background.


# Guitar Roadmap 2.0 Development Rules

The One Guitar Roadmap 2.0 is an independent product module inside the broader The One website.

Before implementing or modifying any feature related to:

- guitar roadmap
- LMS
- lessons
- student progress
- practice
- assignments
- reviews
- checkpoints
- certifications
- learning levels
- Free / Plus / Pro learning features

read these documents first:

- `docs/guitar-roadmap/README.md`
- `docs/guitar-roadmap/student-pain-points.md`
- `docs/guitar-roadmap/membership-model.md`

## Non-negotiable Product Principles

1. Guitar Roadmap is not a traditional video-course catalog.
2. The core outcome is student capability, not course consumption.
3. Watching a lesson does not automatically mean completion.
4. Important learning nodes should follow: Learn → Practice → Apply → Verify.
5. Progress should prioritize demonstrated abilities instead of lesson counts.
6. The primary Level outcomes are:
   - Level 1: 我可以把一首歌完整彈完
   - Level 2: 我的伴奏不再只有一種
   - Level 3: 我開始知道自己在彈什麼
   - Level 4: 我可以慢慢離開樂譜
   - Level 5: 我可以自己改歌、加旋律、加 Solo
   - Level 6: 我可以自己處理一首陌生歌曲
7. Do not change these Level outcome definitions without explicit product approval.
8. Student learning is not assumed to be linear. Product design should support:
   - getting stuck
   - forgetting
   - restarting
   - limited practice time
   - different learning motivations
9. Free / Plus / Pro philosophy:
   - Free = direction
   - Plus = system
   - Pro = results + human verification
10. Do not add LMS features simply because competitors have them.
11. Every Guitar Roadmap feature must clearly support at least one of:
   - student orientation
   - practice
   - progress
   - application
   - retention
   - feedback
   - verification
   - recovery from learning difficulties
12. Avoid hard-coding commercial rules such as human review quotas unless explicitly specified.
13. When requirements conflict with these product principles, surface the conflict before implementing the conflicting behavior.
