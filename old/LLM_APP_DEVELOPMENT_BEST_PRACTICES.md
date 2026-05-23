# LLM-Assisted Application Development - Best Practices

> **Purpose:** Framework-agnostic best practices for building applications with AI assistance.
> **Audience:** Developers working with Claude Code, GitHub Copilot, Cursor, or similar tools.
> **Last Updated:** November 2025

---

## Table of Contents

1. [Context Preservation](#context-preservation)
2. [Prompt Engineering](#prompt-engineering)
3. [Code Architecture](#code-architecture)
4. [Testing & Validation](#testing--validation)
5. [Documentation](#documentation)
6. [Session Management](#session-management)
7. [Common Pitfalls](#common-pitfalls)

---

## Context Preservation

### **Problem: AI Loses Context Between Sessions**

LLMs have token limits and don't retain memory across sessions. Without proper context preservation, you waste time re-explaining decisions.

### **Solution: Hybrid Context System**

#### **1. AI_CONTEXT.md (Write-Ahead Log)**

Create a session-based log with:
- Design decisions and "why"
- Technical insights and learnings
- Open questions and blockers
- File modification history

**Template:**
```markdown
## Session YYYY-MM-DD

### Summary
[One-line description of session work]

### Features Completed
- ✅ Feature name
  - Problem it solved
  - Technical implementation
  - Files modified

### Design Decisions
- **Decision:** What was decided
- **Why:** Rationale
- **Alternatives:** What was considered
- **Impact:** Consequences

### Technical Learnings
- Pattern: [Name]
  - When to use it
  - Code example
  - Gotchas

### Open Questions
- Q: [Question]
  - Options: [A, B, C]
  - Need to decide: [When/why]
```

**Update Frequency:** After each major feature or design decision

**Archive Strategy:**
- Rotate to `docs/archive/AI_CONTEXT_YYYY-MM.md` monthly
- Keep current file under 50KB for quick scanning

---

#### **2. Rich Commit Messages**

Include context in commit bodies:

```bash
feat: Add user authentication with JWT

CONTEXT:
- Users requested ability to save preferences across devices
- Evaluated OAuth vs JWT - chose JWT for simplicity

DECISIONS:
- 7-day token expiration (balance security vs UX)
- Refresh tokens stored in httpOnly cookies
- Access tokens in memory only (no localStorage)

TECHNICAL:
- Used jose library for JWT signing/verification
- Middleware pattern for protected routes
- Error handling with specific codes (401, 403)

NEXT:
- Add password reset flow
- Implement rate limiting
- Add session management UI

REFS: docs/AUTH_DESIGN.md
```

**Benefits:**
- Permanent record in git history
- Searchable with `git log --grep`
- AI can read git log for context

---

#### **3. Design Documents**

Create spec docs for major features:

```
docs/
├── FEATURE_NAME_DESIGN.md    # Detailed spec before building
├── ARCHITECTURE.md            # System overview
├── API_PATTERNS.md            # Common API patterns
└── TECH_DECISIONS.md          # ADR (Architecture Decision Records)
```

**When to create:**
- Feature needs >2 hours of work
- Multiple implementation approaches exist
- Decision will impact future work

**Reference in:**
- Commit messages
- AI_CONTEXT.md
- Code comments

---

## Prompt Engineering

### **Principle: Be Specific, Not Vague**

❌ **Bad Prompt:**
> "Add authentication to the app"

✅ **Good Prompt:**
> "Add JWT-based authentication to the Express API. Users should log in with email/password. Store JWT in httpOnly cookie with 7-day expiration. Protected routes should check for valid token in middleware. Use bcrypt for password hashing (10 rounds). Return user object (id, email, name) on successful login."

---

### **Pattern: Provide Examples**

When asking for code generation, provide:
1. **Input example**
2. **Expected output example**
3. **Edge cases to handle**

**Example:**
> "Create a function to parse food descriptions into macros.
>
> Input: '2 scrambled eggs with cheese'
> Output: { kcal: 220, protein_g: 16, carbs_g: 2, fat_g: 16, fiber_g: 0 }
>
> Input: 'grilled chicken breast'
> Output: Ask for quantity or assume 4oz serving
>
> Handle:
> - Missing quantities → use standard portions
> - Cooking methods → adjust macros (fried vs grilled)
> - Multi-item meals → separate into array"

---

### **Pattern: Constrain the Solution Space**

Reduce ambiguity by specifying:
- **Tech stack:** "Use React Native with TypeScript, not JavaScript"
- **Libraries:** "Use react-native-paper for UI components, not NativeBase"
- **Patterns:** "Follow repository pattern for data access"
- **Constraints:** "Must work offline, sync when online"

---

### **Pattern: Ask for Alternatives**

Get AI to think through trade-offs:

> "We need to store user preferences. What are the options for:
> 1. Local storage (AsyncStorage, SQLite, MMKV)
> 2. Cloud sync (Firebase, Supabase, custom API)
>
> For each option, explain:
> - Pros/cons
> - Performance implications
> - Offline support
> - Cost
>
> Recommend best option for our use case (nutrition tracking app, 10K users, budget-conscious)."

---

## Code Architecture

### **Principle: Design for AI Understandability**

Write code that AI can easily reason about in future sessions.

---

### **Pattern: Clear Separation of Concerns**

```typescript
// ❌ Bad: Mixed concerns
async function handleLogin(email: string, password: string) {
  const user = await db.query('SELECT * FROM users WHERE email = ?', [email]);
  if (!user) throw new Error('Not found');
  const valid = await bcrypt.compare(password, user.password);
  if (!valid) throw new Error('Invalid');
  const token = jwt.sign({ id: user.id }, SECRET);
  res.cookie('token', token, { httpOnly: true });
  return { id: user.id, email: user.email };
}

// ✅ Good: Separated concerns
// services/auth.ts
class AuthService {
  async validateCredentials(email: string, password: string): Promise<User> {
    const user = await this.userRepo.findByEmail(email);
    if (!user) throw new AuthError('USER_NOT_FOUND');

    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) throw new AuthError('INVALID_PASSWORD');

    return user;
  }

  generateToken(user: User): string {
    return jwt.sign({ id: user.id, email: user.email }, SECRET, {
      expiresIn: '7d'
    });
  }
}

// controllers/auth.controller.ts
async function login(req: Request, res: Response) {
  const { email, password } = req.body;

  const user = await authService.validateCredentials(email, password);
  const token = authService.generateToken(user);

  res.cookie('token', token, { httpOnly: true, secure: true });
  res.json({ user: { id: user.id, email: user.email, name: user.name } });
}
```

**Why AI likes this:**
- Each function has one responsibility
- Easy to understand what each piece does
- Clear boundaries for modifications

---

### **Pattern: Type Everything (TypeScript)**

```typescript
// ❌ Bad: AI has to guess types
async function search(query) {
  const result = await llm.search(query, macros);
  return result;
}

// ✅ Good: Types make intent clear
interface SearchQuery {
  query: string;
  macros: {
    protein_g: number;
    carbs_g: number;
    fat_g: number;
  };
}

interface FoodSearchResult {
  intent: 'food';
  foodName: string;
  macros: Macros;
  fitScore: number;
  recommendation: 'yes' | 'no' | 'maybe';
}

async function searchFood(
  query: string,
  remainingMacros: Macros
): Promise<FoodSearchResult | IngredientSearchResult | RestaurantSearchResult> {
  // Implementation
}
```

**Benefits:**
- AI understands data contracts
- Autocomplete helps AI generate correct code
- Refactoring is safer

---

### **Pattern: Self-Documenting Code**

```typescript
// ❌ Bad: Magic numbers, unclear logic
if (score > 80) {
  return 'good';
} else if (score > 60) {
  return 'fair';
}

// ✅ Good: Named constants, clear intent
const FIT_SCORE_THRESHOLDS = {
  EXCELLENT: 80,
  GOOD: 60,
  FAIR: 40,
} as const;

function getFitRating(score: number): 'excellent' | 'good' | 'fair' | 'poor' {
  if (score >= FIT_SCORE_THRESHOLDS.EXCELLENT) return 'excellent';
  if (score >= FIT_SCORE_THRESHOLDS.GOOD) return 'good';
  if (score >= FIT_SCORE_THRESHOLDS.FAIR) return 'fair';
  return 'poor';
}
```

---

### **Pattern: Provider-Agnostic Abstractions**

When integrating external services (LLMs, APIs), create abstractions:

```typescript
// ✅ Good: Provider-agnostic interface
interface LLMProvider {
  extractMacros(description: string): Promise<Macros>;
  searchFood(query: string): Promise<SearchResult>;
}

class ClaudeProvider implements LLMProvider {
  async extractMacros(description: string): Promise<Macros> {
    // Claude-specific implementation
  }
}

class ChatGPTProvider implements LLMProvider {
  async extractMacros(description: string): Promise<Macros> {
    // ChatGPT-specific implementation
  }
}

class GeminiProvider implements LLMProvider {
  async extractMacros(description: string): Promise<Macros> {
    // Gemini-specific implementation
  }
}

// Usage
class LLMService {
  private provider: LLMProvider;

  async init() {
    const settings = await db.getAppSettings();

    if (settings.llm_provider === 'claude') {
      this.provider = new ClaudeProvider(settings.claude_api_key);
    } else if (settings.llm_provider === 'chatgpt') {
      this.provider = new ChatGPTProvider(settings.openai_api_key);
    } else if (settings.llm_provider === 'gemini') {
      this.provider = new GeminiProvider(settings.gemini_api_key);
    }
  }

  async extractMacros(description: string): Promise<Macros> {
    return this.provider.extractMacros(description);
  }
}
```

**Benefits:**
- Easy to swap providers
- Easy to A/B test
- Easy to add new providers
- AI understands the pattern and can extend it

---

## Testing & Validation

### **Pattern: Validate AI-Generated Code**

Never assume AI code works perfectly. Always:

1. **Read the code** - Understand what it does
2. **Test manually** - Run it with real data
3. **Check edge cases** - What if input is null? Empty? Huge?
4. **Verify external calls** - Did API call succeed? Correct endpoint?

---

### **Pattern: Create Ground Truth Datasets**

For AI features (like nutrition extraction), validate against known data:

```typescript
// tests/llm-validation.test.ts
const GROUND_TRUTH = [
  {
    input: "1 large egg, scrambled",
    expected: { kcal: 90, protein_g: 6, carbs_g: 1, fat_g: 7 },
    tolerance: { kcal: 10, protein_g: 1, carbs_g: 1, fat_g: 1 }
  },
  // ... 100 more test cases from USDA FoodData Central
];

test('LLM nutrition extraction accuracy', async () => {
  let passedCount = 0;

  for (const testCase of GROUND_TRUTH) {
    const result = await llmService.extractMacros(testCase.input);

    const withinTolerance =
      Math.abs(result.kcal - testCase.expected.kcal) <= testCase.tolerance.kcal &&
      Math.abs(result.protein_g - testCase.expected.protein_g) <= testCase.tolerance.protein_g;
      // ... check other macros

    if (withinTolerance) passedCount++;
  }

  const accuracy = passedCount / GROUND_TRUTH.length;
  console.log(`LLM Accuracy: ${(accuracy * 100).toFixed(1)}%`);

  expect(accuracy).toBeGreaterThan(0.90); // 90% accuracy threshold
});
```

---

### **Pattern: Log AI Responses for Debugging**

```typescript
async function extractMacros(description: string): Promise<Macros> {
  const prompt = `...`;

  const response = await anthropic.messages.create({ ... });

  // Log for debugging
  console.log('[LLM] Input:', description);
  console.log('[LLM] Response length:', response.content[0].text.length);
  console.log('[LLM] Response preview:', response.content[0].text.substring(0, 200));

  const parsed = JSON.parse(response.content[0].text);
  console.log('[LLM] Parsed result:', parsed);

  return parsed;
}
```

**Benefits:**
- Easier to debug failures
- Track LLM behavior over time
- Identify prompt improvements

---

## Documentation

### **Pattern: Code Comments for "Why," Not "What"**

```typescript
// ❌ Bad: Explains what (obvious from code)
// Loop through items and add them up
let total = 0;
for (const item of items) {
  total += item.price;
}

// ✅ Good: Explains why (non-obvious reasoning)
// Use 75% quality weight because user studies showed people care more
// about restaurant reviews than perfect macro fit for ordering out
const combinedScore = fitScore * 0.25 + qualityScore * 0.75;
```

---

### **Pattern: Decision Logs (ADRs)**

For major technical decisions, create Architecture Decision Records:

```markdown
# ADR-003: Use SQLite Instead of AsyncStorage

## Status
Accepted (2025-01-15)

## Context
Need to store food entries, daily targets, and cached nutrition data.
Considered AsyncStorage (simple) vs SQLite (queryable).

## Decision
Use SQLite via expo-sqlite

## Rationale
- AsyncStorage limited to key-value pairs
- Need complex queries (food entries by date, search cache)
- SQLite supports offline-first, sync later
- Better performance for >1000 entries
- Migrations supported

## Consequences
- More complex setup (schema migrations)
- Requires SQL knowledge
- File size ~200KB (acceptable)
- Can add full-text search later

## Alternatives Considered
- AsyncStorage: Too limited for queries
- Realm: Overkill, large bundle size
- WatermelonDB: Reactive, but learning curve
```

---

## Session Management

### **Pattern: Know When to Start Fresh**

Start a new AI session when:
- ✅ Token usage >80% (AI performance degrades)
- ✅ Switching to unrelated feature area
- ✅ AI starts hallucinating or giving bad suggestions
- ✅ You want a "fresh perspective" on a problem

Continue current session when:
- ✅ Building related features
- ✅ Context is valuable (deep in implementation)
- ✅ Token usage <80%

---

### **Pattern: Session Handoff Checklist**

Before ending a session:

1. **Commit all changes**
   ```bash
   git add .
   git commit -m "Session summary"
   ```

2. **Update AI_CONTEXT.md**
   - What was built
   - Key decisions
   - Open questions
   - Next steps

3. **Update design docs** (if applicable)

4. **Run archiving script** (if file size exceeded)

5. **Push to remote**
   ```bash
   git push
   ```

When starting new session:

1. **AI reads:**
   - `AI_CONTEXT.md`
   - `git log --oneline -10`
   - Relevant design docs
   - Current todo list

2. **You provide:**
   - "Continue where we left off"
   - Or: "Start new feature: [name]"

---

## Common Pitfalls

### **Pitfall 1: Assuming AI Remembers Previous Sessions**

❌ **Bad:**
> "Continue implementing the authentication feature"

✅ **Good:**
> "Continue implementing JWT authentication. Last session we:
> - Created User model and schema
> - Implemented password hashing with bcrypt
> - Added login endpoint
>
> Next: Create protected route middleware and refresh token logic.
> See AI_CONTEXT.md for design decisions."

---

### **Pitfall 2: Not Validating AI Suggestions**

AI can suggest code that:
- Uses deprecated APIs
- Has subtle bugs
- Doesn't follow your architecture patterns
- Uses libraries you don't have installed

**Always review and test!**

---

### **Pitfall 3: Letting AI Make All Design Decisions**

AI can suggest technical solutions, but **you** should decide:
- Product direction
- User experience trade-offs
- Business logic
- Which features to build

Use AI for "how," not "what."

---

### **Pitfall 4: Over-Relying on AI for Complex Logic**

AI is great for:
- ✅ Boilerplate code
- ✅ TypeScript types
- ✅ API integrations
- ✅ UI layouts

AI struggles with:
- ⚠️ Complex algorithms (verify carefully)
- ⚠️ Security-critical code (review thoroughly)
- ⚠️ Performance-sensitive code (benchmark)

---

### **Pitfall 5: Not Providing Enough Context**

If AI generates bad code, first ask:
- "Did I give enough context?"
- "Did I specify constraints?"
- "Did I provide examples?"

Often the problem is the prompt, not the AI.

---

## Summary: The Golden Rules

1. **📝 Preserve Context** - AI_CONTEXT.md + rich commits + design docs
2. **🎯 Be Specific** - Detailed prompts get better results
3. **🏗️ Design for AI** - Clean architecture, types, separation of concerns
4. **✅ Always Validate** - Test AI code, check edge cases
5. **📚 Document Why** - Explain non-obvious decisions
6. **🔄 Manage Sessions** - Know when to continue vs start fresh
7. **🤔 Stay in Control** - AI suggests, you decide

---

## Session-Specific Learnings

### **Lesson: Atomic Commits (Code + Context Together)**

**Problem Discovered (Nov 2025):**
When code and AI_CONTEXT.md updates were committed separately, context updates were often forgotten, leading to orphaned code changes without explanation.

**Solution:**
Always commit code changes and AI_CONTEXT.md updates **together in one atomic commit**.

**Why This Works:**
- ✅ **Unforgettable** - Can't commit code without committing context
- ✅ **Associated** - Code and explanation stay linked in git history
- ✅ **Atomic** - One commit = one complete logical change
- ✅ **Reviewable** - Future devs see what and why together

**Example:**
```bash
# ❌ BAD: Separate commits (easy to forget step 2)
git add src/feature.tsx
git commit -m "feat: Add feature"
# ... get distracted, never update AI_CONTEXT.md

# ✅ GOOD: Atomic commit
git add src/feature.tsx AI_CONTEXT.md
git commit -m "feat: Add feature

Implemented [description].

Updated AI_CONTEXT.md:
- Documented design decision to use X instead of Y
- Added technical learning about pattern Z
"
```

**Rule of Thumb:**
If the commit changes functionality, AI_CONTEXT.md should be updated in the same commit.

**Exceptions:**
- Trivial fixes (typos, formatting) - no context update needed
- Documentation-only changes - obviously don't need code
- Refactoring that doesn't change behavior - may not need context update

---

### **Lesson: Update Context During Session, Not At End**

**Problem Discovered (Nov 2025):**
Planning to "update context at the end of the session" leads to:
- Lost details (forgot why decisions were made)
- Session crashes/disconnects before context saved
- Incomplete documentation

**Solution:**
Update AI_CONTEXT.md **immediately after** completing each feature or making each design decision.

**Workflow:**
```
1. Build feature
2. Update AI_CONTEXT.md with details
3. Commit both together ← DO THIS NOW
4. Move to next feature
```

**Why This Matters:**
- 🔥 Sessions can crash unexpectedly (memory limits, network issues)
- 🧠 Fresh context is more detailed and accurate
- 📊 Git history shows complete story
- 🚀 Next session can pick up immediately

**Red Flags:**
- "I'll update context when I'm done with all features"
- Making 5+ commits without touching AI_CONTEXT.md
- Relying on memory to document decisions later

---

## Appendix: Tools & Resources

### **AI Coding Assistants**
- **Claude Code** - Best for complex reasoning, architecture discussions
- **GitHub Copilot** - Best for inline code completion
- **Cursor** - Best for codebase-aware editing
- **ChatGPT Code Interpreter** - Best for data analysis, prototyping

### **Context Management**
- `git log --grep` - Search commit history
- `git blame` - See when/why code changed
- ADRs (Architecture Decision Records)
- Design docs in `docs/`

### **Testing AI Features**
- Unit tests with known ground truth
- A/B testing (Claude vs ChatGPT vs Gemini)
- User feedback loops
- Logging and monitoring

---

**Created:** November 2025
**For:** Nulog project (generalizable to any app)
**Maintained by:** Development team
