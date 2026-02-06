Here's what I'd consider the strongest agent-native primitives—services where the API surface is clean enough that agents can operate them reliably without handholding:

**Databases & State**
- **Supabase** - Postgres + auto-generated REST/GraphQL APIs. Agents grok SQL natively, and the REST layer means no driver complexity.
- **PlanetScale** - MySQL with branching. The serverless HTTP API is agent-friendly.
- **Turso** - SQLite at the edge with HTTP API. Dead simple mental model.
- **Upstash** - Redis and Kafka over HTTP. Stateless calls, no connection management.
- **Neon** - Serverless Postgres with branching and HTTP access.

**File Storage**
- **Cloudflare R2** - S3-compatible, no egress fees. Agents understand S3 operations cold.
- **S3** itself - The canonical object store. Every agent has seen a million examples.
- **Tigris** - S3-compatible, globally distributed, simpler pricing.

**Compute**
- **Modal** - Python functions as infrastructure. Agents can reason about `@app.function()` decorators naturally.
- **Fly.io** - Dockerfile → globally distributed. The flyctl CLI is very agent-parseable.
- **Railway** - Git push deploys with straightforward env var management.
- **Render** - Similar simplicity to Railway.
- **Heroku** - Still solid for the "just deploy this" case.

**Email**
- **Resend** - Clean REST API, minimal concepts (just send HTML/text).
- **Postmark** - Similar simplicity, good deliverability.
- **SendGrid** - More complex but agents know it well from training data.
- **Loops** - If you need transactional + marketing in one.

**Auth**
- **Clerk** - Drop-in auth with good REST APIs.
- **Supabase Auth** - If you're already on Supabase.
- **WorkOS** - Enterprise SSO without the complexity.

**Queues & Background Jobs**
- **Inngest** - Event-driven functions with great DX. Agents can reason about step functions.
- **Trigger.dev** - Similar model, good TypeScript support.
- **Upstash QStash** - HTTP-based message queue, no connections.

**Edge/CDN**
- **Cloudflare Workers** - JS/Wasm at the edge. Agents understand the fetch handler pattern.
- **Vercel Edge Functions** - Same idea, tighter Next.js integration.

**Payments**
- **Stripe** - The API agents have seen most. Clean REST, good docs.
- **Lemon Squeezy** - Simpler for SaaS/digital products.

**Search**
- **Typesense** - Simple REST API, easy to reason about.
- **Meilisearch** - Similar, self-hostable.
- **Algolia** - More complex but well-documented.

**The pattern** that makes these agent-native:
1. HTTP/REST over persistent connections
2. Declarative config over imperative setup
3. Minimal auth complexity (API keys > OAuth flows)
4. Good error messages
5. Lots of training data (popular = better agent performance)
