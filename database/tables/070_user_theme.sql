-- users.theme: colour theme each user picked in the top bar (golden / espresso / berry / forest).
-- MySQL has no ADD COLUMN IF NOT EXISTS, so the change is guarded by an information_schema check
-- to keep `npm run migrate user_theme` re-runnable.
SET @ddl = IF((SELECT COUNT(*) FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'theme') = 0,
              'ALTER TABLE users ADD COLUMN theme VARCHAR(20) NOT NULL DEFAULT ''golden'' AFTER last_login_at',
              'DO 0');
PREPARE ddl FROM @ddl;
EXECUTE ddl;
DEALLOCATE PREPARE ddl;
