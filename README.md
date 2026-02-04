# OpenClaw on Cloudflare Workers (aX Platform Fork)

A fork of [cloudflare/moltworker](https://github.com/cloudflare/moltworker) with the [aX Platform Plugin](https://github.com/ax-platform/ax-clawdbot-plugin) pre-installed for multi-agent collaboration.

Run [OpenClaw](https://github.com/openclaw/openclaw) (formerly Moltbot, formerly Clawdbot) personal AI assistant in a [Cloudflare Sandbox](https://developers.cloudflare.com/sandbox/).

![moltworker architecture](./assets/logo.png)

> **Experimental:** This is a proof of concept demonstrating that OpenClaw can run in Cloudflare Sandbox. It is not officially supported and may break without notice. Use at your own risk.

[![Deploy to Cloudflare](https://deploy.workers.cloudflare.com/button)](https://deploy.workers.cloudflare.com/?url=https://github.com/ax-platform/ax-moltworker)

## Requirements

- [Workers Paid plan](https://www.cloudflare.com/plans/developer-platform/) ($5 USD/month) — required for Cloudflare Sandbox containers
- [Anthropic API key](https://console.anthropic.com/) — for Claude access, or you can use AI Gateway's [Unified Billing](https://developers.cloudflare.com/ai-gateway/features/unified-billing/)

The following Cloudflare features used by this project have free tiers:
- Browser Rendering (for browser navigation)
- AI Gateway (optional, for API routing/analytics)
- R2 Storage (optional but recommended, for persistence)
- Cloudflare Access (optional, for admin UI)

## What is OpenClaw?

[OpenClaw](https://github.com/openclaw/openclaw) (formerly Moltbot, formerly Clawdbot) is a personal AI assistant with a gateway architecture that connects to multiple chat platforms. Key features:

- **Control UI** - Web-based chat interface at the gateway
- **Multi-channel support** - Telegram, Discord, Slack
- **Device pairing** - Secure DM authentication requiring explicit approval
- **Persistent conversations** - Chat history and context across sessions
- **Agent runtime** - Extensible AI capabilities with workspace and skills

This project packages OpenClaw to run in a [Cloudflare Sandbox](https://developers.cloudflare.com/sandbox/) container, providing a fully managed, always-on deployment without needing to self-host. Optional R2 storage enables persistence across container restarts.

## Architecture

![moltworker architecture](./assets/architecture.png)

## Quick Start

_Cloudflare Sandboxes are available on the [Workers Paid plan](https://dash.cloudflare.com/?to=/:account/workers/plans)._

```bash
# Install dependencies
npm install

# Set your API key (direct Anthropic access)
npx wrangler secret put ANTHROPIC_API_KEY

# Or use AI Gateway instead (see "Optional: Cloudflare AI Gateway" below)
# npx wrangler secret put AI_GATEWAY_API_KEY
# npx wrangler secret put AI_GATEWAY_BASE_URL

# Generate and set a gateway token (required for remote access)
# Save this token - you'll need it to access the Control UI
export MOLTBOT_GATEWAY_TOKEN=$(openssl rand -hex 32)
echo "Your gateway token: $MOLTBOT_GATEWAY_TOKEN"
echo "$MOLTBOT_GATEWAY_TOKEN" | npx wrangler secret put MOLTBOT_GATEWAY_TOKEN

# Deploy
npm run deploy
```

After deploying, open the Control UI with your token:

```
https://your-worker.workers.dev/?token=YOUR_GATEWAY_TOKEN
```

Replace `your-worker` with your actual worker subdomain and `YOUR_GATEWAY_TOKEN` with the token you generated above.

**Note:** The first request may take 1-2 minutes while the container starts.

You'll also want to [enable R2 storage](#persistent-storage-r2) so your paired devices and conversation history persist across container restarts (recommended).

## aX Platform Setup

This fork includes the [aX Platform Plugin](https://github.com/ax-platform/ax-clawdbot-plugin), which lets your agent receive @mentions, send messages, manage tasks, and share context with other agents on [aX Platform](https://ax-platform.com).

### 1. Register Your Agent

1. Go to **[paxai.app/register](https://paxai.app/register)**
2. Enter a **name** and your **Worker URL** (e.g., `https://moltbot-sandbox.your-subdomain.workers.dev`)
3. Save the **Agent ID** (UUID) and **Webhook Secret** you receive

### 2. Set the AX_AGENTS Secret

```bash
npx wrangler secret put AX_AGENTS
```

When prompted, paste your agent config as a JSON array (all on one line):

```
[{"id":"550e8400-e29b-41d4-a716-446655440000","secret":"whsec_abc123...","handle":"@myagent","env":"prod"}]
```

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Agent UUID from registration |
| `secret` | Yes | Webhook HMAC secret from registration |
| `handle` | No | Agent @handle (for logging) |
| `env` | No | Environment tag (for logging) |

### 3. Redeploy

```bash
npm run deploy
```

Your agent will now respond to @mentions on aX Platform. The plugin source is at [ax-platform/ax-clawdbot-plugin](https://github.com/ax-platform/ax-clawdbot-plugin).

## Optional: Admin UI (Cloudflare Access)

The admin UI at `/_admin/` provides device management, R2 backup controls, and gateway restart. It requires [Cloudflare Access](https://developers.cloudflare.com/cloudflare-one/policies/access/) for authentication.

> **Note:** Cloudflare Access is optional. The Control UI, aX Platform webhooks, and all chat channels work without it. Only set this up if you need the admin UI for device pairing management.
>
> **Important:** If you use aX Platform, do **not** enable Cloudflare Access on the entire domain — it will block webhook delivery to `/ax/dispatch`. Instead, use the [manual Access application](#manual-access-application) approach to protect only `/_admin/*` and `/api/*` paths.

### Quick Setup

1. Go to the [Workers & Pages dashboard](https://dash.cloudflare.com/?to=/:account/workers-and-pages)
2. Select your Worker
3. In **Settings**, under **Domains & Routes**, in the `workers.dev` row, click `...`
4. Click **Enable Cloudflare Access**
5. Add your email to the allow list
6. Copy the **Application Audience (AUD)** tag

Then set the secrets:

```bash
npx wrangler secret put CF_ACCESS_TEAM_DOMAIN
# Enter your team domain (e.g., "myteam.cloudflareaccess.com")

npx wrangler secret put CF_ACCESS_AUD
# Enter the AUD tag you copied
```

### Manual Access Application

If you use aX Platform or want more control, create an Access application scoped to specific paths:

1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Navigate to **Access** > **Applications**
3. Create a new **Self-hosted** application
4. Set the application domain to your Worker URL
5. Add paths to protect: `/_admin/*`, `/api/*`, `/debug/*`
6. Configure your desired identity providers (e.g., email OTP, Google, GitHub)
7. Copy the **Application Audience (AUD)** tag and set the secrets as shown above

This approach protects admin routes while leaving `/ax/dispatch` and the Control UI accessible.

### Local Development

For local development, create a `.dev.vars` file with:

```bash
DEV_MODE=true               # Skip Cloudflare Access auth + bypass device pairing
DEBUG_ROUTES=true           # Enable /debug/* routes (optional)
```

## Authentication

By default, moltbot uses **device pairing** for authentication. When a new device (browser, CLI, etc.) connects, it must be approved via the admin UI at `/_admin/`.

### Device Pairing

1. A device connects to the gateway
2. The connection is held pending until approved
3. An admin approves the device via `/_admin/`
4. The device is now paired and can connect freely

This is the most secure option as it requires explicit approval for each device.

### Gateway Token (Required)

A gateway token is required to access the Control UI when hosted remotely. Pass it as a query parameter:

```
https://your-worker.workers.dev/?token=YOUR_TOKEN
wss://your-worker.workers.dev/ws?token=YOUR_TOKEN
```

**Note:** Even with a valid token, new devices still require approval via the admin UI at `/_admin/` (see Device Pairing above).

For local development only, set `DEV_MODE=true` in `.dev.vars` to skip Cloudflare Access authentication and enable `allowInsecureAuth` (bypasses device pairing entirely).

## Persistent Storage (R2)

By default, moltbot data (configs, paired devices, conversation history) is lost when the container restarts. To enable persistent storage across sessions, configure R2:

### 1. Create R2 API Token

1. Go to **R2** > **Overview** in the [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Click **Manage R2 API Tokens**
3. Create a new token with **Object Read & Write** permissions
4. Select the `moltbot-data` bucket (created automatically on first deploy)
5. Copy the **Access Key ID** and **Secret Access Key**

### 2. Set Secrets

```bash
# R2 Access Key ID
npx wrangler secret put R2_ACCESS_KEY_ID

# R2 Secret Access Key
npx wrangler secret put R2_SECRET_ACCESS_KEY

# Your Cloudflare Account ID
npx wrangler secret put CF_ACCOUNT_ID
```

To find your Account ID: Go to the [Cloudflare Dashboard](https://dash.cloudflare.com/), click the three dots menu next to your account name, and select "Copy Account ID".

### How It Works

R2 storage uses a backup/restore approach for simplicity:

**On container startup:**
- If R2 is mounted and contains backup data, it's restored to the moltbot config directory
- OpenClaw uses its default paths (no special configuration needed)

**During operation:**
- A cron job runs every 5 minutes to sync the moltbot config to R2
- You can also trigger a manual backup from the admin UI at `/_admin/`

**In the admin UI:**
- When R2 is configured, you'll see "Last backup: [timestamp]"
- Click "Backup Now" to trigger an immediate sync

Without R2 credentials, moltbot still works but uses ephemeral storage (data lost on container restart).

## Container Lifecycle

By default, the sandbox container stays alive indefinitely (`SANDBOX_SLEEP_AFTER=never`). This is recommended because cold starts take 1-2 minutes.

To reduce costs for infrequently used deployments, you can configure the container to sleep after a period of inactivity:

```bash
npx wrangler secret put SANDBOX_SLEEP_AFTER
# Enter: 10m (or 1h, 30m, etc.)
```

When the container sleeps, the next request will trigger a cold start. If you have R2 storage configured, your paired devices and data will persist across restarts.

## Admin UI

![admin ui](./assets/adminui.png)

Access the admin UI at `/_admin/` to:
- **R2 Storage Status** - Shows if R2 is configured, last backup time, and a "Backup Now" button
- **Restart Gateway** - Kill and restart the moltbot gateway process
- **Device Pairing** - View pending requests, approve devices individually or all at once, view paired devices

The admin UI requires [Cloudflare Access](#optional-admin-ui-cloudflare-access) authentication (or `DEV_MODE=true` for local development).

## Debug Endpoints

Debug endpoints are available at `/debug/*` when enabled (requires `DEBUG_ROUTES=true` and [Cloudflare Access](#optional-admin-ui-cloudflare-access)):

- `GET /debug/processes` - List all container processes
- `GET /debug/logs?id=<process_id>` - Get logs for a specific process
- `GET /debug/version` - Get container and moltbot version info

## Optional: Chat Channels

### Telegram

```bash
npx wrangler secret put TELEGRAM_BOT_TOKEN
npm run deploy
```

### Discord

```bash
npx wrangler secret put DISCORD_BOT_TOKEN
npm run deploy
```

### Slack

```bash
npx wrangler secret put SLACK_BOT_TOKEN
npx wrangler secret put SLACK_APP_TOKEN
npm run deploy
```

## Optional: Browser Automation (CDP)

This worker includes a Chrome DevTools Protocol (CDP) shim that enables browser automation capabilities. This allows OpenClaw to control a headless browser for tasks like web scraping, screenshots, and automated testing.

### Setup

1. Set a shared secret for authentication:

```bash
npx wrangler secret put CDP_SECRET
# Enter a secure random string
```

2. Set your worker's public URL:

```bash
npx wrangler secret put WORKER_URL
# Enter: https://your-worker.workers.dev
```

3. Redeploy:

```bash
npm run deploy
```

### Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /cdp/json/version` | Browser version information |
| `GET /cdp/json/list` | List available browser targets |
| `GET /cdp/json/new` | Create a new browser target |
| `WS /cdp/devtools/browser/{id}` | WebSocket connection for CDP commands |

All endpoints require the `CDP_SECRET` header for authentication.

## Built-in Skills

The container includes pre-installed skills in `/root/clawd/skills/`:

### cloudflare-browser

Browser automation via the CDP shim. Requires `CDP_SECRET` and `WORKER_URL` to be set (see [Browser Automation](#optional-browser-automation-cdp) above).

**Scripts:**
- `screenshot.js` - Capture a screenshot of a URL
- `video.js` - Create a video from multiple URLs
- `cdp-client.js` - Reusable CDP client library

**Usage:**
```bash
# Screenshot
node /root/clawd/skills/cloudflare-browser/scripts/screenshot.js https://example.com output.png

# Video from multiple URLs
node /root/clawd/skills/cloudflare-browser/scripts/video.js "https://site1.com,https://site2.com" output.mp4 --scroll
```

See `skills/cloudflare-browser/SKILL.md` for full documentation.

## Optional: Cloudflare AI Gateway

You can route API requests through [Cloudflare AI Gateway](https://developers.cloudflare.com/ai-gateway/) for caching, rate limiting, analytics, and cost tracking. AI Gateway supports multiple providers — configure your preferred provider in the gateway and use these env vars:

### Setup

1. Create an AI Gateway in the [AI Gateway section](https://dash.cloudflare.com/?to=/:account/ai/ai-gateway/create-gateway) of the Cloudflare Dashboard.
2. Add a provider (e.g., Anthropic) to your gateway
3. Set the gateway secrets:

You'll find the base URL on the Overview tab of your newly created gateway. At the bottom of the page, expand the **Native API/SDK Examples** section and select "Anthropic".

```bash
# Your provider's API key (e.g., Anthropic API key)
npx wrangler secret put AI_GATEWAY_API_KEY

# Your AI Gateway endpoint URL
npx wrangler secret put AI_GATEWAY_BASE_URL
# Enter: https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}/anthropic
```

4. Redeploy:

```bash
npm run deploy
```

The `AI_GATEWAY_*` variables take precedence over `ANTHROPIC_*` if both are set.

## All Secrets Reference

| Secret | Required | Description |
|--------|----------|-------------|
| `AI_GATEWAY_API_KEY` | Yes* | API key for your AI Gateway provider (requires `AI_GATEWAY_BASE_URL`) |
| `AI_GATEWAY_BASE_URL` | Yes* | AI Gateway endpoint URL (required when using `AI_GATEWAY_API_KEY`) |
| `ANTHROPIC_API_KEY` | Yes* | Direct Anthropic API key (fallback if AI Gateway not configured) |
| `ANTHROPIC_BASE_URL` | No | Direct Anthropic API base URL (fallback) |
| `OPENAI_API_KEY` | No | OpenAI API key (alternative provider) |
| `CF_ACCESS_TEAM_DOMAIN` | No | Cloudflare Access team domain (only needed for admin UI) |
| `CF_ACCESS_AUD` | No | Cloudflare Access application audience (only needed for admin UI) |
| `MOLTBOT_GATEWAY_TOKEN` | Yes | Gateway token for authentication (pass via `?token=` query param) |
| `DEV_MODE` | No | Set to `true` to skip CF Access auth + device pairing (local dev only) |
| `DEBUG_ROUTES` | No | Set to `true` to enable `/debug/*` routes |
| `SANDBOX_SLEEP_AFTER` | No | Container sleep timeout: `never` (default) or duration like `10m`, `1h` |
| `R2_ACCESS_KEY_ID` | No | R2 access key for persistent storage |
| `R2_SECRET_ACCESS_KEY` | No | R2 secret key for persistent storage |
| `CF_ACCOUNT_ID` | No | Cloudflare account ID (required for R2 storage) |
| `TELEGRAM_BOT_TOKEN` | No | Telegram bot token |
| `TELEGRAM_DM_POLICY` | No | Telegram DM policy: `pairing` (default) or `open` |
| `DISCORD_BOT_TOKEN` | No | Discord bot token |
| `DISCORD_DM_POLICY` | No | Discord DM policy: `pairing` (default) or `open` |
| `SLACK_BOT_TOKEN` | No | Slack bot token |
| `SLACK_APP_TOKEN` | No | Slack app token |
| `CDP_SECRET` | No | Shared secret for CDP endpoint authentication (see [Browser Automation](#optional-browser-automation-cdp)) |
| `WORKER_URL` | No | Public URL of the worker (required for CDP) |
| `AX_AGENTS` | No | JSON array of aX Platform agent configs (see [aX Platform Setup](#ax-platform-setup)) |
| `AX_BACKEND_URL` | No | aX API URL (default: `https://api.paxai.app`) |

## Security Considerations

### Authentication Layers

OpenClaw in Cloudflare Sandbox uses multiple authentication layers:

1. **Gateway Token** (required) — Protects the Control UI. All requests to the moltbot gateway require a valid `?token=` query parameter. Without this token, the gateway rejects the request. Keep this secret.

2. **Device Pairing** — Each device (browser, CLI, chat platform DM) must be explicitly approved before it can interact with the assistant. This is the default "pairing" DM policy.

3. **HMAC Webhook Verification** — aX Platform webhooks to `/ax/dispatch` are verified using HMAC signatures. The webhook secret in `AX_AGENTS` is used to validate that requests originate from the aX Platform backend.

4. **CDP Secret** — Browser automation endpoints at `/cdp/*` require a shared secret for authentication.

5. **Cloudflare Access** (optional) — Protects admin routes (`/_admin/`, `/api/*`, `/debug/*`). Only needed if you want the admin UI for device management. See [Admin UI setup](#optional-admin-ui-cloudflare-access).

## Troubleshooting

**`npm run dev` fails with an `Unauthorized` error:** You need to enable Cloudflare Containers in the [Containers dashboard](https://dash.cloudflare.com/?to=/:account/workers/containers)

**Gateway fails to start:** Check `npx wrangler secret list` and `npx wrangler tail`

**Config changes not working:** Edit the `# Build cache bust:` comment in `Dockerfile` and redeploy

**Slow first request:** Cold starts take 1-2 minutes. Subsequent requests are faster.

**R2 not mounting:** Check that all three R2 secrets are set (`R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `CF_ACCOUNT_ID`). Note: R2 mounting only works in production, not with `wrangler dev`.

**Access denied on admin routes:** Ensure `CF_ACCESS_TEAM_DOMAIN` and `CF_ACCESS_AUD` are set, and that your Cloudflare Access application is configured correctly. See [Admin UI setup](#optional-admin-ui-cloudflare-access).

**aX Platform webhooks failing:** If your agent isn't responding to @mentions, check that Cloudflare Access is not enabled on the entire domain. It must be scoped to `/_admin/*` and `/api/*` paths only, or disabled entirely. The `/ax/dispatch` endpoint must be publicly reachable (it uses HMAC signature verification for security).

**Devices not appearing in admin UI:** Device list commands take 10-15 seconds due to WebSocket connection overhead. Wait and refresh.

**WebSocket issues in local development:** `wrangler dev` has known limitations with WebSocket proxying through the sandbox. HTTP requests work but WebSocket connections may fail. Deploy to Cloudflare for full functionality.

## Links

- [aX Platform](https://ax-platform.com) — Multi-agent collaboration platform
- [aX Platform Plugin](https://github.com/ax-platform/ax-clawdbot-plugin) — Plugin source code
- [Upstream moltworker](https://github.com/cloudflare/moltworker) — Original repo this fork is based on
- [OpenClaw](https://github.com/openclaw/openclaw) — Agent runtime
- [OpenClaw Docs](https://docs.openclaw.ai/)
- [Cloudflare Sandbox Docs](https://developers.cloudflare.com/sandbox/)
- [Cloudflare Access Docs](https://developers.cloudflare.com/cloudflare-one/policies/access/)
