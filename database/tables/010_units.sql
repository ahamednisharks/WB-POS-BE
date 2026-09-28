-- active_* generated columns are NULL for deleted rows, so the UNIQUE keys only apply to live rows.
CREATE TABLE IF NOT EXISTS units (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  unit_name      VARCHAR(30)  NOT NULL,
  short_code     VARCHAR(5)   NOT NULL,
  allow_decimal  TINYINT(1)   NOT NULL DEFAULT 0,
  status         TINYINT(1)   NOT NULL DEFAULT 1,
  is_deleted     TINYINT(1)   NOT NULL DEFAULT 0,
  created_by     INT          NULL,
  created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by     INT          NULL,
  updated_at     DATETIME     NULL,
  active_name    VARCHAR(30)  GENERATED ALWAYS AS (IF(is_deleted = 0, unit_name, NULL)) VIRTUAL,
  active_code    VARCHAR(5)   GENERATED ALWAYS AS (IF(is_deleted = 0, short_code, NULL)) VIRTUAL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_units_name (active_name),
  UNIQUE KEY uq_units_code (active_code),
  KEY ix_units_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
