# 连接 Vercel（前端）

仓库：https://github.com/2222a2/AI-

公网地址：**https://ai-xi-ashen-31.vercel.app**  
（Vercel → Project → Domains；以当前 Production 域名为准。旧地址 `ai-yuyu24.vercel.app` 已废弃，勿再用于 Auth / CORS。）

## 已上线环境变量

Vercel → Project → Settings → Environment Variables：

```env
NEXT_PUBLIC_SUPABASE_URL=https://lwiymsdmqdpzsbjbbccn.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=（同本地 .env.local 的 anon key）
NEXT_PUBLIC_API_URL=https://shared-planner-backend-production-a10a.up.railway.app
```

- Root Directory = **`web`**（monorepo 根是仓库根）
- 不要把 `service_role` 写进前端环境变量
- 修改变量后需 **Redeploy**

## Supabase Auth（公网必改）

Authentication → URL Configuration：

- Site URL = `https://ai-xi-ashen-31.vercel.app`
- Redirect URLs 至少包含：
  - `https://ai-xi-ashen-31.vercel.app/**`
  - `http://localhost:3000/**`（本地调试仍保留）

## 重新部署

Vercel Dashboard → Deployments → Redeploy

或：

```powershell
cd web
npx vercel login
npx vercel link
npx vercel --prod
```

## 本地开发

```powershell
npm run dev
```

打开 http://localhost:3000

`.env.local` 中 `NEXT_PUBLIC_API_URL` 可指向公网 Railway，或改成 `http://localhost:8080` 走本地 API。

## 访问说明

`*.vercel.app` 在部分网络下可能超时或「链接中断」。部署状态为 Ready 仍可能打不开，属访问路径问题，可换网络 / 代理后再打开登录页验收。
