FROM node:18-alpine AS base

# Install dependencies only when needed
FROM base AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.

RUN apk add --no-cache libc6-compat

WORKDIR /docs

# Install dependencies based on the preferred package manager
COPY package.json yarn.lock* package-lock.json* ./

# TODO(nderjung): This --force needs to be removed
RUN npm install --force

# Rebuild the source code only when needed
FROM base AS builder

WORKDIR /docs

COPY --from=deps /docs/node_modules ./node_modules

COPY . .

ENV NEXT_TELEMETRY_DISABLED 1

RUN yarn build --no-lint

# Production image, copy all the files and run next
FROM base AS runner

WORKDIR /docs

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN set -xe; \
    addgroup --system --gid 1001 nodejs; \
    adduser --system --uid 1001 nextjs

COPY --from=builder /docs/public ./public

# Set the correct permission for prerender cache
RUN set -xe; \
    mkdir .next; \
    chown nextjs:nodejs .next

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /docs/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /docs/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
