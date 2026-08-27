# 多作品集系统 · 部署指引

## 一、本次改动概览（v3）

| 模块 | 说明 |
|---|---|
| 数据库 | `portfolios` 表新增 `preview_count`（预览 N 页）/ `expire_at`（有效期）列；`config` 表新增 `email_config` / `notify_state` 键（代码自动维护） |
| 后台 | 重构为 **3 标签**：概览 / 作品集 / 站点设置；内容设置、页面管理、文件管理并入「作品集」详情页 |
| 站点设置 | 系统信息（标题/描述）、主题（6 套预设）、网站图标（favicon 上传）、水印（合并为单一文字框，`{名字}` 语法加粗）、联系方式、邮件提醒、管理密码 |
| 访问控制 | 预览 N 页（密码作品集免费看前 N 页，其余锁定）、有效期控制（到期自动失效）、访问上限 |
| 水印 | 动态水印（附加访客 IP + 访问时间，防转发截图）、胶囊/斜纹平铺双样式 |
| 邮件提醒 | Resend 集成：访客浏览时推送提醒（10 分钟内合并一封），支持测试邮件 |
| 统计 | 近 14 天访问量图表改为真实数据驱动（东八区对齐，含当日高亮） |
| 路由 | `/thanks.html` 等静态页显式放行（修复被 `/{slug}` 路由误拦截的问题） |

## 二、部署步骤（已有站点升级到 v3）

```bash
cd portfolio-app

# 1. 登录 Cloudflare（会打开浏览器授权）
npx wrangler login

# 2. 执行 v3 数据库迁移（仅需一次）
npx wrangler d1 execute portfolio-showcase-db --remote --file=schema_v3.sql

# 3. 部署代码
npx wrangler pages deploy . --project-name=portfolio-showcase

# 4. 验证
#    打开 https://你的域名/admin 登录后：
#    - 「站点设置」标签页应出现（系统信息/主题/图标/水印/联系/邮件/密码）
#    - 任意作品集「管理」→「访问控制」应出现「预览页数」「有效期」
```

> **自动迁移兜底**：即使忘记执行 `schema_v3.sql`，API 首次被调用时 `ensureSchema()` 会自动补齐缺失的列（幂等，重复执行无副作用）。
> 旧站点（v1）请先依次执行 `schema.sql` → `schema_v2.sql` → `schema_v3.sql`。

## 三、全新站点部署

```bash
npx wrangler d1 execute portfolio-showcase-db --remote --file=schema.sql
npx wrangler d1 execute portfolio-showcase-db --remote --file=schema_v2.sql
npx wrangler d1 execute portfolio-showcase-db --remote --file=schema_v3.sql
npx wrangler pages deploy . --project-name=portfolio-showcase
```

> 全新站点无旧数据时，首次打开 `/admin` 会自动创建「我的第一个作品集」。

## 四、功能说明

### 站点设置（系统级，全局生效）
- **系统信息**：站点标题（浏览器标签页 + 分享卡片）、站点描述（SEO meta / OG 标签）。
- **主题**：6 套预设强调色（清新绿/商务蓝/典雅紫/活力橙/浪漫粉/极简黑），点击即生效，前台与管理后台同步。
- **网站图标**：上传 PNG/JPG/WebP，自动缩放为 favicon，前台 `<link rel=icon>` 按版本号自动刷新缓存。
- **水印**：一个文字框搞定（用 `{名字}` 包裹需要加粗的部分，如 `内容由 {李明} 创作`）；可开启动态水印（附加访客 IP 与访问时间）；胶囊 / 斜纹平铺双样式实时预览。
- **邮件提醒**：在 [resend.com](https://resend.com) 免费注册获取 API Key，填入接收邮箱即可；访客浏览作品集时推送提醒（同一时段 10 分钟合并一封）。API Key 保存后不再回显。

### 作品集级访问控制
- **访问密码**：PBKDF2 哈希存储；验证通过后签发 HttpOnly Cookie（7 天）。
- **预览 N 页**：密码作品集可设置免费预览页数，未解锁访客只能看前 N 页，其后页面在图片接口层直接 404（无法绕过）。
- **有效期**：到期后 `/api/config` 返回 `expired: true`，前台显示已失效提示；管理端凭文件令牌不受影响。
- **访问上限**：达到上限后返回 `blocked: true`。

### 管理端文件令牌（ft）
管理后台加载受密码保护作品集的缩略图 / 页面图时，URL 附带 `?ft=` HMAC 签名令牌（2 小时有效），绕过前台访问限制；该令牌不可用于公开页面。

## 五、架构要点

- **存储隔离**：每个作品集的 R2 对象带 `pf{id}_` 前缀，删除作品集时按前缀清理。
- **图片 URL**：`/api/file/{slug}/page/v{版本}/{页码}.webp`，旧格式 `/api/file/page/...` 兼容 default 作品集。
- **密码保护**：受保护作品集的图片与配置均绕过共享边缘缓存，防止按 URL 绕过密码；`Cache-Control: no-store`。
- **水印**：`capsule`（磨砂胶囊底部居中）/ `tile`（斜纹平铺全屏，防截图分享），在后台「站点设置 → 水印」中配置，全局生效。
- **动态水印数据源**：前台 `GET /api/track` 返回访客 IP 与服务器时间（`no-store`），用于拼接动态水印文字。
- **SEO**：`/sitemap.xml` 动态列出已发布作品集；`/{slug}` 直达路由返回完整前台页面；站点标题/描述支持后台实时修改。

## 六、本地开发调试

```bash
# 用本地 D1/R2 模拟环境启动（无需真实 Cloudflare 账号）
npx wrangler pages dev public --compatibility-date 2024-12-30

# 初始化本地数据库（首次）
npx wrangler d1 execute portfolio-showcase-db --local --file=schema.sql
npx wrangler d1 execute portfolio-showcase-db --local --file=schema_v2.sql
npx wrangler d1 execute portfolio-showcase-db --local --file=schema_v3.sql

# 管理密码默认不存在，需手工插入（PBKDF2 格式）或通过 /admin 首次初始化流程创建
```

## 七、待办（二期）

- 作品集复制功能

> 已完成（原二期项）：Resend 邮件通知（访客浏览提醒 + 测试邮件 + 10 分钟节流合并）、后台水印实时预览（胶囊/斜纹平铺双样式切换）、作品集列表卡片化排序（上下移持久化）、作品集访问排行统计、动态水印（IP + 时间）、预览 N 页 / 有效期控制、站点设置中心（主题/图标/描述/邮件/密码）。
> 已下线：使用申请功能（`/api/request` 与感谢页表单已删除，`schema_v2.sql` 含 `DROP TABLE IF EXISTS requests` 幂等清理）。
