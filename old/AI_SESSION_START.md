# Starting a New AI Coding Session

> **Purpose:** Standard procedure for onboarding AI assistants to the Nulog codebase.
> **Use this:** When starting a fresh Claude Code / Cursor / GitHub Copilot session.

---

## Quick Start (2 minutes)

### **Step 1: Read Context Files** (AI should do this automatically)

```
1. AI_CONTEXT.md - Current session context and recent decisions
2. git log --oneline -10 - Latest 10 commits
3. docs/ARCHITECTURE.md - System overview (if exists)
4. Todo list - Current task list
```

### **Step 2: Review Active Work**

Check what's in progress:
```bash
git status
git diff
```

### **Step 3: Confirm Understanding**

AI should summarize:
- What we're currently building
- Last session's accomplishments
- Next steps from AI_CONTEXT.md
- Any blockers or open questions

---

## Detailed Onboarding Procedure

### **1. Context Restoration**

#### **Primary Source: AI_CONTEXT.md**
Read the current session section at the top of the file. It contains:
- Summary of recent work
- Design decisions with rationale
- Technical architecture insights
- Files modified
- Open questions
- Next steps

**Location:** `/AI_CONTEXT.md`

**What to focus on:**
- "Summary" - High-level overview
- "Design Decisions" - Understanding the "why"
- "Technical Learnings" - Patterns to follow
- "Next Steps" - What to work on next

---

#### **Secondary Source: Git History**

```bash
# See latest commits with context
git log --oneline -10

# See detailed commit messages (include design decisions)
git log -5 --format=medium

# See what changed recently
git diff HEAD~5..HEAD --stat
```

**What to look for:**
- Recent feature additions
- Bug fixes and their causes
- Refactoring decisions

---

#### **Tertiary Source: Design Docs**

Check `docs/` directory for feature specs:

```bash
ls docs/

# Common docs:
docs/
├── ARCHITECTURE.md           # System overview
├── DINNER_WHEEL_DESIGN.md    # Feature: Dinner Wheel spec
├── LLM_EVALUATION_PLAN.md    # LLM testing methodology
├── LLM_APP_DEVELOPMENT_BEST_PRACTICES.md  # General AI dev guide
└── archive/                  # Old AI_CONTEXT files (compressed)
```

**When to read:**
- Building or modifying a feature with a design doc
- Need to understand system architecture
- Want to know why something was built a certain way

---

### **2. Understand Current State**

#### **Check Working Directory**

```bash
# Any uncommitted changes?
git status

# What's been modified?
git diff

# Any staged changes?
git diff --cached
```

**Ask user:**
- "Should I continue the work in progress?"
- "Or start fresh on a new feature?"

---

#### **Check Todo List**

The todo list tracks all pending work. Look for:
- Items marked `in_progress` - What we're currently doing
- Items marked `pending` - What's queued up
- Recently `completed` items - Recent context

**Location:** Maintained by TodoWrite tool during session

---

### **3. Identify Next Task**

Based on context review, identify what to work on next:

#### **Option A: Continue In-Progress Work**
If todo list shows `in_progress` items:
- Confirm with user: "I see we're working on [X]. Should I continue?"
- Review related files
- Check for any blockers in AI_CONTEXT.md

#### **Option B: Start New Feature**
If nothing in progress:
- Check "Next Steps" in AI_CONTEXT.md
- Review pending todo items
- Ask user which priority to tackle

#### **Option C: Bug Fix**
If user reports an issue:
- Reproduce the error
- Check recent commits for related changes
- Review AI_CONTEXT.md for related design decisions

---

### **4. Confirm Approach**

Before coding, confirm:
- ✅ Understand the requirement
- ✅ Know which files to modify
- ✅ Aware of design constraints (from AI_CONTEXT.md)
- ✅ Following established patterns

**Ask user if uncertain:**
- "I'm planning to [approach]. Does that align with your vision?"
- "Should I follow the pattern in [existing file]?"

---

## Example Session Start

### **User Prompt:**
> "Let's continue where we left off."

### **AI Response:**

**Context Restored:**
I've reviewed:
- ✅ AI_CONTEXT.md - Last session (2025-11-18)
- ✅ Git log - Latest 5 commits
- ✅ Todo list - 28 items (8 completed, 1 in progress)

**Current State:**
- **Last completed:** Search screen with LLM auto-detection
- **In progress:** AI context preservation system
- **Next planned:** Dinner Wheel feature (mood/category selection)

**Summary of Recent Work:**
- Built unified Search screen (food/ingredient/restaurant)
- Removed fit scores from Add Food screen (misleading for single items)
- Created AI_CONTEXT.md system for session continuity
- Fixed database method call bug (getTodaysFoodEntries → getFoodEntriesByDate)
- Fixed JSON parsing bug (arrays vs objects)

**Key Decisions from Last Session:**
1. Skip delivery platform APIs (DoorDash/UberEats require partner access)
2. Use LLM price estimation for menu items (~$12 format)
3. Dinner Wheel selects mood/category, not specific restaurant
4. Maintain LLM flexibility but will evaluate which is best

**Next Steps (from AI_CONTEXT.md):**
1. Build Dinner Wheel UI with 8 mood/category slices
2. Add LLM price estimation to restaurant recommendations
3. Integrate with navigation

**Ready to proceed. What would you like to work on?**
- A) Continue with Dinner Wheel implementation
- B) Address a specific issue
- C) Start different feature

---

## Recovery from Compressed Archives

If you need context from older sessions:

```bash
# List archived contexts
ls docs/archive/

# Read compressed archive
gunzip -c docs/archive/AI_CONTEXT_2025-11.md.gz | less

# Extract if needed for AI to read
gunzip docs/archive/AI_CONTEXT_2025-11.md.gz
# Now at: docs/archive/AI_CONTEXT_2025-11.md
```

**When to read archives:**
- Feature was designed months ago
- Need to understand old design decisions
- Tracking down when a pattern was established

---

## Best Practices During Session

### **IMPORTANT: Update Context as You Go**

**After Each Feature or Major Change:**

1. ✅ Write the code changes
2. ✅ Update AI_CONTEXT.md with feature details, design decisions, and learnings
3. ✅ Update todo list (mark completed, add new tasks)
4. ✅ **Commit code + context together in one atomic commit**

**Why Commit Together?**
- Ensures context is never forgotten or orphaned
- Code and explanation stay associated in git history
- One commit = one complete logical change
- Easier to review what was done and why

**Example Workflow:**
```bash
# 1. Complete feature + update AI_CONTEXT.md
# Edit code files...
# Edit AI_CONTEXT.md to document the feature...

# 2. Commit everything together (ATOMIC)
git add src/components/NewFeature.tsx \
        AI_CONTEXT.md

git commit -m "feat: Add new feature

Implemented [description of what was built].

Updated AI_CONTEXT.md:
- Added feature documentation
- Documented design decision to use X instead of Y
- Updated Next Steps section
"

# 3. Continue to next task
```

**Red Flags (Don't Do This):**
- ❌ Committing code without updating AI_CONTEXT.md
- ❌ Making 5+ commits before updating context
- ❌ Planning to "update context at the end" (session may crash!)
- ❌ Separate commits for code and context (easy to forget the second one)
- ❌ Not documenting design decisions as they happen

**Rule of Thumb:** If the commit changes functionality, AI_CONTEXT.md should be updated in the same commit.

---

## Session Handoff (Ending Current Session)

Before ending, ensure continuity for next session:

### **1. Final Review**
```bash
# Check that all work is committed
git status

# Verify AI_CONTEXT.md is current
# Should reflect all work done this session
```

### **2. Update SESSION_SUMMARY.md (Optional)**
If major features were completed:
```bash
# Update SESSION_SUMMARY.md with session highlights
git add SESSION_SUMMARY.md
git commit -m "docs: Update session summary"
```

### **3. Push to Remote**
```bash
git push origin main
```

### **4. Archive if Needed**
If AI_CONTEXT.md exceeds 50KB:
```bash
./scripts/archive-ai-context.sh
```

---

## Troubleshooting

### **"AI doesn't understand the context"**

**Solutions:**
1. Check if AI_CONTEXT.md is up to date
2. Provide specific file references: "See src/services/llm.ts:954 for pattern"
3. Quote relevant sections from AI_CONTEXT.md
4. Show git commit that introduced the pattern

---

### **"AI suggests something we already decided against"**

**Solutions:**
1. Point to decision in AI_CONTEXT.md: "We decided against X because Y (see AI_CONTEXT.md line 123)"
2. Reference the commit that implemented current approach
3. Update AI_CONTEXT.md to make decision more prominent

---

### **"Context file is too long"**

**Solutions:**
1. Run archive script: `./scripts/archive-ai-context.sh`
2. Archive rotates monthly or when >50KB
3. Keeps current session focused

---

## Best Practices

### **Do:**
- ✅ Always read AI_CONTEXT.md before coding
- ✅ Update context after major features
- ✅ Include "why" in design decisions
- ✅ Reference design docs in commits
- ✅ Ask clarifying questions when uncertain

### **Don't:**
- ❌ Skip context review and guess
- ❌ Make big decisions without checking past decisions
- ❌ Forget to update AI_CONTEXT.md after important work
- ❌ Let AI_CONTEXT.md grow indefinitely (archive it)

---

## Quick Reference

### **Files to Read (Priority Order):**
1. `AI_CONTEXT.md` - Recent decisions and context (current + last session)
2. `docs/summaries/YYYY-MM.md` - Monthly summaries (1 page each, ultra-compressed)
3. `git log --oneline -10` - Latest commits
4. `docs/FEATURE_NAME_DESIGN.md` - Specific feature specs
5. Todo list - Current task status

### **Scripts:**
```bash
./scripts/update-ai-context.sh    # Update context log
./scripts/archive-ai-context.sh   # Archive when >50KB
```

### **Reading Archives:**
```bash
gunzip -c docs/archive/AI_CONTEXT_2025-01.md.gz | less
```

---

**Created:** November 2025
**For:** Nulog project
**Maintained by:** Development team
