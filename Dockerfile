# syntax=docker/dockerfile:1

FROM node:22-alpine AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

FROM base AS deps
WORKDIR /app
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile

FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
ARG NEXT_PUBLIC_APP_URL=https://ai-image-gen-mcp.hansondev.me
ENV NEXT_PUBLIC_APP_URL=$NEXT_PUBLIC_APP_URL
# Build-time stubs: some modules read these at import time during `next build`.
# Real values are injected at runtime by Coolify.
RUN NEXT_PUBLIC_APP_URL=$NEXT_PUBLIC_APP_URL \
    POSTGRES_URL=postgresql://build:build@localhost:5432/build \
    BETTER_AUTH_SECRET=build-time-only-secret-0123456789abcdef \
    POLAR_ACCESS_TOKEN=polar_ \
    POLAR_WEBHOOK_SECRET=polar_ \
    POLAR_PRODUCT_ID_STARTER=polar_starter \
    POLAR_PRODUCT_ID_PLUS=polar_plus \
    POLAR_PRODUCT_ID_PRO=polar_pro \
    pnpm run build:ci

FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
RUN addgroup --system --gid 1001 nodejs \
  && adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# sharp's platform-native binaries ship as optionalDependencies that Next.js
# standalone file-tracing does not follow (and its traced copies are dangling
# symlinks). Reinstall sharp in a clean dir and splice the result in.
RUN mkdir -p /tmp/sharp && cd /tmp/sharp \
  && npm install --no-save --no-audit --no-fund sharp@0.35.4 \
  && for d in node_modules/*; do rm -rf "/app/node_modules/${d##*/}"; done \
  && cp -a node_modules/. /app/node_modules/ \
  && rm -rf /tmp/sharp

USER nextjs
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"
CMD ["node", "server.js"]
