# CFW Social — Admin Runbook

Operational procedures for recovering from errors, managing access, and maintaining the CFW Social application.

---

## Stuck Run Recovery

### Symptom

A `Run` has `status = "running"` for hours, or `status = "pending"` indefinitely.

### Diagnosis

```sql
-- Find stuck runs (running for > 1 hour)
SELECT id, agent_id, workspace_id, status, started_at, prompt
FROM runs
WHERE status = 'running'
  AND started_at < NOW() - INTERVAL '1 hour';

-- Find orphaned pending runs (never started)
SELECT id, agent_id, workspace_id, status, started_at
FROM runs
WHERE status = 'pending'
  AND started_at < NOW() - INTERVAL '30 minutes';
```

### Recovery options

**Option 1: Mark as failed (if agent definitely crashed)**
```sql
UPDATE runs
SET status = 'failed',
    completed_at = NOW()
WHERE id = 'run_abc123'
  AND status = 'running';
```

**Option 2: Retry the run**
1. Note the `runId`, `workspaceId`, `agentId`, and `prompt`
2. Create a new run with the same parameters
3. Old run can be left as `failed` or manually cleaned up

**Option 3: Check agent health**
```bash
# Check if cfw-agent is responsive
curl -s http://localhost:8081/health

# Check agent logs
tail -f /Users/vasanth/Code/cfw/cfw-agent/logs/agent.log
```

**Option 4: Force-complete (if outputs exist but status stuck)**
```sql
UPDATE runs
SET status = 'done',
    completed_at = NOW()
WHERE id = 'run_abc123'
  AND status = 'running'
  AND EXISTS (SELECT 1 FROM outputs WHERE run_id = 'run_abc123');
```

### Prevention

- Set a `RUN_TIMEOUT_MS` in cfw-agent (default should be < 1 hour)
- Monitor `running` run count with alerting
- Implement heartbeat: cfw-agent writes `RunEvent` every 30 seconds while active

---

## Key Rotation

### API Key rotation

```sql
-- List active keys for a brand
SELECT id, name, prefix, last_used_at, created_at
FROM api_keys
WHERE brand_id = 'brand_abc'
  AND is_active = true;

-- Revoke old key (soft delete)
UPDATE api_keys
SET is_active = false
WHERE id = 'key_old123';

-- Create new key via UI or direct DB insert
-- (plaintext is shown once, never stored)
```

### Encryption key rotation

`ENCRYPTION_KEY` is shared between cfw-social and cfw-agent. Rotation requires:

1. Generate new key (64-char hex)
2. Re-encrypt all sensitive columns:
   - `Brand.openclawApiKey`
   - `Brand.pfmProjectApiKey`
   - `PlatformConnection.accessTokenEnc`
   - `TelegramBot.botToken`
   - etc.
3. Update `.env` on both services
4. Restart both services
5. Verify by decrypting a test value

**Note:** There is no automated rotation script. This is a manual DBA operation.

---

## Account Deletion

### User-initiated

`POST /api/v1/me/delete-account`

1. Sets `User.deletionRequestedAt = NOW()`
2. Schedules hard delete for +30 days
3. Cancels active Stripe subscriptions
4. Sends confirmation email

### Admin-initiated

```sql
-- Immediate soft delete
UPDATE users
SET deleted_at = NOW(),
    deletion_requested_at = NOW()
WHERE id = 'user_abc';

-- Cascade to brands (or handle per-brand)
UPDATE brands
SET deleted_at = NOW()
WHERE owner_id = 'user_abc';
```

### Hard delete (after 30 days)

```sql
-- This would run as a scheduled job
DELETE FROM users WHERE deletion_requested_at < NOW() - INTERVAL '30 days';
-- Cascades trigger on all related tables
```

### GDPR right to erasure

Same as user-initiated deletion. The 30-day window allows for:
- Cancellation (user changes mind)
- Data export (user requests their data)
- Audit trail retention (logs kept longer)

---

## Billing Plan Changes

### Upgrading a brand

**Via Stripe Checkout:**
```bash
curl -X POST https://app.cfw.social/api/v1/billing/checkout \
  -H "Content-Type: application/json" \
  -d '{"plan": "creator", "brandId": "brand_abc"}'
```

**Direct DB (admin only, for comping/free trials):**
```sql
UPDATE brands
SET plan = 'pro',
    trial_ends_at = NOW() + INTERVAL '14 days'
WHERE id = 'brand_abc';
```

### Downgrading

**Via Stripe Portal:**
```bash
curl -X POST https://app.cfw.social/api/v1/billing/portal \
  -H "Content-Type: application/json" \
  -d '{"brandId": "brand_abc"}'
```

**Direct DB (admin only):**
```sql
UPDATE brands
SET plan = 'free',
    stripe_subscription_id = NULL
WHERE id = 'brand_abc';
```

### Plan feature gates

Code should check `Brand.plan` before enabling features:

| Feature | Free | Creator | Pro |
|---|---|---|---|
| Runs per month | 10 | 100 | Unlimited |
| Team members | 1 | 3 | 10 |
| Platforms | 3 | 7 | 10 |
| API access | No | Yes | Yes |
| Custom integrations | No | No | Yes |

---

## Database Maintenance

### Checking Prisma connection

```bash
# From cfw-social repo
psql $DATABASE_URL -c "SELECT 1;"

# Or via Prisma
pnpm prisma db pull
```

### Running migrations

```bash
# From cfw-social repo
pnpm prisma migrate deploy
```

### Vacuum and analyze

```sql
-- Run weekly
VACUUM ANALYZE;

-- For large tables
VACUUM ANALYZE run_events;
VACUUM ANALYZE conversation_messages;
```

### Index bloat check

```sql
SELECT
  schemaname,
  tablename,
  indexname,
  pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY pg_relation_size(indexname::regclass) DESC;
```

---

## Log Investigation

### Agent audit logs

```sql
-- Find expensive runs
SELECT
  brand_id,
  conversation_id,
  tool_name,
  llm_tokens_in,
  llm_tokens_out,
  llm_cost_usd,
  created_at
FROM agent_audit_logs
WHERE created_at > NOW() - INTERVAL '24 hours'
ORDER BY llm_cost_usd DESC
LIMIT 20;

-- Find output filter triggers
SELECT
  brand_id,
  conversation_id,
  tool_name,
  output_filter_triggered,
  created_at
FROM agent_audit_logs
WHERE output_filter_triggered = true
  AND created_at > NOW() - INTERVAL '7 days';
```

### Security audit logs

```sql
-- Find suspicious actions
SELECT
  user_id,
  action,
  entity_type,
  entity_id,
  metadata,
  ip,
  created_at
FROM audit_logs
WHERE action LIKE 'brand.%'
  OR action LIKE 'billing.%'
  OR action LIKE 'platform.%'
ORDER BY created_at DESC
LIMIT 50;
```

---

## Performance Tuning

### Slow queries to watch

```sql
-- Run events without index
SELECT * FROM run_events WHERE run_id = '...' ORDER BY seq;
-- Should use index: [runId, seq] (unique)

-- Posts by brand and status
SELECT * FROM posts WHERE brand_id = '...' AND status = 'scheduled';
-- Should use index: [brandId, status]

-- Conversations by brand and channel
SELECT * FROM brand_conversations WHERE brand_id = '...' AND channel = 'telegram';
-- Should use index: [brandId, channel]
```

### Connection pooling

Prisma connection pool defaults:
- `connection_limit = num_cpus * 2 + 1`
- For Neon/PostgreSQL: monitor `max_connections`

### Redis

Used for:
- Session caching (Better Auth cookieCache)
- Rate limit counters
- Webhook deduplication (update_id)

Monitor:
```bash
redis-cli INFO memory
redis-cli INFO stats
```

---

## Disaster Recovery

### Database backup

Neon provides point-in-time recovery. For self-hosted:
```bash
pg_dump $DATABASE_URL > backup_$(date +%Y%m%d).sql
```

### R2 backup

Cloudflare R2 has built-in versioning. For critical assets:
```bash
rclone sync r2:cfw-social-backup s3:disaster-recovery-bucket
```

### Service recovery

| Service | Recovery step |
|---|---|
| cfw-social | `cd cfw-social && pnpm start` |
| cfw-agent | `cd cfw-agent && pnpm tsx --env-file=.env src/server.ts` |
| Postgres | Neon dashboard or `pg_ctl start` |
| Redis | `redis-server` |

### Rollback procedure

1. Identify failing commit
2. `git revert <commit>`
3. `pnpm install && pnpm build`
4. Restart service
5. Run smoke tests (`c-cfw-social-smoke-test/smoke.mjs`)
