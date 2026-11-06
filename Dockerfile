# 根目录 Dockerfile：Railway 新版 UI 无 Root Directory 字段时的兜底方案
# 构建上下文 = 仓库根目录，所有 COPY 路径以仓库根为基准
FROM node:20-alpine AS deps
WORKDIR /app
COPY supabase/services/api/package.json supabase/services/api/package-lock.json ./
RUN npm ci

FROM node:20-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY supabase/services/api/package.json supabase/services/api/package-lock.json ./
COPY supabase/services/api/tsconfig.json ./
COPY supabase/services/api/src ./src
RUN npm run build \
  && npm prune --omit=dev

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=8080

COPY --from=build /app/package.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
# AI 任务名称改写规则（运行时读取 renwumingcheng）
COPY supabase/services/api/renwumingcheng ./renwumingcheng

EXPOSE 8080
CMD ["npm", "start"]
