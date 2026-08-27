-- =========================================================
-- v3 迁移：访问控制增强 + 站点设置（在 v2 基础上执行，仅需一次）
-- v2 → v3 变化：
--   1. portfolios 新增 preview_count（预览 N 页，0=不限制）
--   2. portfolios 新增 expire_at（有效期时间戳 ms，0=永久有效）
--   3. config 表新增 email_config / notify_state 键（代码自动维护，无需手工插入）
-- 全新部署：先执行 schema.sql → schema_v2.sql → 本文件
-- 注意：v2 已创建 visits.slug，本文件不再重复添加（重复 ALTER 会中止整个脚本）
--      存量旧库若缺 visits.slug，代码侧 ensureSchema() 会自动补列。
-- =========================================================

ALTER TABLE portfolios ADD COLUMN preview_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE portfolios ADD COLUMN expire_at INTEGER NOT NULL DEFAULT 0;
