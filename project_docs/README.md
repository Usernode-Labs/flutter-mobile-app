# Project Documentation

This directory contains project management and tracking documents.

## 📁 Files

### [TASKS.md](./TASKS.md)
**Active task tracking and backlog**
- Current sprint tasks
- Prioritized backlog
- Blocked items
- Notes and context

**Update frequency**: Daily/Weekly

---

### [SUGGESTIONS.md](./SUGGESTIONS.md)
**AI suggestions and decision log**
- Records all AI suggestions
- Your decisions (accepted/rejected/deferred)
- Rationale for each decision
- Status tracking

**Update frequency**: After each AI interaction

---

### [CHANGELOG.md](./CHANGELOG.md)
**Completed work log**
- Date-ordered change history
- What was added/changed/removed
- Impact metrics
- Breaking changes

**Update frequency**: After each significant change

---

### [DECISIONS.md](./DECISIONS.md)
**Architecture Decision Records (ADR)**
- Major technical decisions
- Context and alternatives considered
- Consequences (pros/cons)
- Status and dates

**Update frequency**: When making architectural decisions

---

## 🔄 Workflow

### When Starting a New Task
1. Add to `TASKS.md` under appropriate priority
2. Move to "Current Sprint" when starting
3. Mark as `[x]` when complete
4. Log in `CHANGELOG.md`

### When Receiving AI Suggestions
1. Document in `SUGGESTIONS.md`
2. Make your decision (accept/reject/defer)
3. Add rationale
4. If accepted, add to `TASKS.md`

### When Making Architecture Decisions
1. Create new ADR in `DECISIONS.md`
2. Document context, decision, alternatives
3. List consequences
4. Reference in `CHANGELOG.md` when implemented

### At End of Sprint/Week
1. Review completed tasks
2. Update `CHANGELOG.md` with summary
3. Move incomplete tasks to next sprint
4. Archive completed ADRs if needed

---

## 📊 Quick Start

### Today's Tasks
Check `TASKS.md` → "Current Sprint" section

### Recent Changes
Check `CHANGELOG.md` → Top entry

### Why We Made That Decision
Check `DECISIONS.md` → Search by topic

### What AI Suggested Last Time
Check `SUGGESTIONS.md` → Latest entry

---

## 🎯 Best Practices

**Do:**
- ✅ Update documents as you go (not at end of week)
- ✅ Be specific in task descriptions
- ✅ Document **why** not just **what**
- ✅ Keep CHANGELOG factual and measurable
- ✅ Record AI suggestions even if rejected

**Don't:**
- ❌ Wait to document (you'll forget context)
- ❌ Be vague ("fix bugs" → "fix wallet balance calculation")
- ❌ Delete history (mark as done/rejected instead)
- ❌ Duplicate info across files (link instead)

---

## 🔗 Integration with Git

These files are **version controlled** so you can:
- Track changes over time
- See decision evolution
- Revert if needed
- Share with team

Commit messages should reference these docs:
```
git commit -m "feat: add Riverpod state management (TASKS.md #1, ADR-002)"
```

---

## 📱 Alternative Tools

If you prefer external tools, consider:

**Free:**
- GitHub Issues (already have repo)
- Notion (all-in-one workspace)
- Trello (kanban boards)
- Linear (issue tracking)

**Paid:**
- Jira (enterprise PM)
- Asana (team collaboration)
- ClickUp (all-in-one)

**This approach vs external tools:**
- ✅ No external accounts needed
- ✅ Version controlled
- ✅ Lives with code
- ✅ Markdown (simple, portable)
- ❌ No fancy UI
- ❌ No notifications/reminders
- ❌ Manual updates

---

## 📝 Templates

All files include templates at the bottom for easy copy-paste.

---

**Created**: 2025-10-03
**Last Updated**: 2025-10-03
**Maintainer**: Development Team
