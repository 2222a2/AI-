# ShareTodo AI — Web（Next.js）

本地前端，对接 Supabase Auth + 业务表。

## 1. 配置环境变量

```bash
copy .env.local.example .env.local
```

编辑 `.env.local`，填入 Supabase → Project Settings → API 中的：

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`

**不要**写入 `service_role`。

公网：https://ai-yuyu24.vercel.app  
API：`NEXT_PUBLIC_API_URL=https://shared-planner-backend-production-a10a.up.railway.app`

Supabase Authentication → URL Configuration：

- Site URL: `https://ai-yuyu24.vercel.app`
- Redirect URLs: `https://ai-yuyu24.vercel.app/**`、`http://localhost:3000/**`

## 2. 安装与启动

```bash
npm install
npm run dev
```

打开 [http://localhost:3000/login](http://localhost:3000/login)

## 3. 验收

1. 用新邮箱注册（或登录）
2. 进入 `/app`，应看到 Profile 昵称 + 个人空间（角色 `owner`）
3. 在 Supabase Table Editor 核对 `profiles` / `spaces` / `space_members`

## 路由

| 路径 | 说明 |
|------|------|
| `/` | 已登录跳转 `/app`，否则 `/login` |
| `/login` | 注册 / 登录 |
| `/app` | 登录后首页（验收自动建档） |
