CREATE TABLE IF NOT EXISTS categories (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  category_name  VARCHAR(50)  NOT NULL,
  image_url      VARCHAR(255) NULL,
  display_order  INT          NOT NULL DEFAULT 0,
  status         TINYINT(1)   NOT NULL DEFAULT 1,
  is_deleted     TINYINT(1)   NOT NULL DEFAULT 0,
  created_by     INT          NULL,
  created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by     INT          NULL,
  updated_at     DATETIME     NULL,
  active_name    VARCHAR(50)  GENERATED ALWAYS AS (IF(is_deleted = 0, category_name, NULL)) VIRTUAL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_categories_name (active_name),
  KEY ix_categories_status (status),
  KEY ix_categories_order (display_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
