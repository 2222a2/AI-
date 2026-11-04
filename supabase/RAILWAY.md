# 连接 Railway（Dashboard 操作清单）

本机若无法安装 Railway CLI（访问 GitHub releases 超时），请用网页完成连接。

仓库：https://github.com/2222a2/AI-  
后端代码在 `supabase/` 子目录，其中已有 `Dockerfile` + `railway.toml`（builder = DOCKERFILE）。

**公网后端：** https://shared-planner-backend-production-a10a.up.railway.app  

**健康检查：** https://shared-planner-backend-production-a10a.up.railway.app/health  

**前端：** https://ai-xi-ashen-31.vercel.app  
（旧前端域名 `ai-yuyu24.vercel.app` 已废弃；`CORS_ORIGIN` 必须与当前 Vercel Production 域名一致。）

## 1. 关联 GitHub 仓库

1. 打开 https://railway.app → 进入你的项目  
2. 若还没有服务： **New → GitHub Repo** → 选 `AI-`  
3. 若已有服务： **Settings → Source** 确认 Repo 为 `2222a2/AI-`，Branch = `main`

## 2. 构建设置（重要）

**Settings**：

| 项 | 值 |
|----|-----|
| Root Directory | **`supabase`**（Dockerfile 与 railway.toml 在 `supabase/` 下） |
| Builder | Dockerfile（或由 `railway.toml` 指定） |
| 自定义 Build Command | **清空**（不要写 `cd services/api && npm …`） |
| 自定义 Start Command | **清空**（Dockerfile 已有 `CMD`） |

## 3. 环境变量 Variables

必填：

```text
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
DEEPSEEK_API_KEY=
```

公网建议（与前端域名对齐）：

```text
CORS_ORIGIN=https://ai-xi-ashen-31.vercel.app,http://localhost:3000
CRON_SECRET=一串随机字符
```

`PORT` 一般不用填（Railway 自动注入）。

改完 Variables 后务必 **Redeploy**（本地 `services/api/.env` 不会同步到 Railway）。

## 4. 公网域名

**Settings → Networking → Generate Domain**

当前域名：`https://shared-planner-backend-production-a10a.up.railway.app`

浏览器打开：`https://shared-planner-backend-production-a10a.up.railway.app/health`  

应返回：`{"ok":true,"service":"shared-planner-api",...}`

## 5. 前端对接

Vercel / 本地 `web/.env.local`：

```env
NEXT_PUBLIC_API_URL=https://shared-planner-backend-production-a10a.up.railway.app
```

然后 Redeploy 前端。

同时确认 Supabase Auth 的 Site URL / Redirect 为：

- `https://ai-xi-ashen-31.vercel.app`
- `https://ai-xi-ashen-31.vercel.app/**`

## 6. Healthcheck 失败时

Deploy Logs 若出现 `Missing required env`：补全第 3 步变量再部署。  

`railway.toml` 中 `healthcheckPath = /health`，勿改成其它路径。

镜像使用 **Node 22**（`Dockerfile` → `node:22-alpine`），以满足 `@supabase/supabase-js` 要求。  

本地开发也请用 Node 22+。

## CLI（可选，网络可用时）

```powershell
npm install -g @railway/cli
railway login
cd supabase
railway link
railway up
```
