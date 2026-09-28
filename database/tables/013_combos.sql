CREATE TABLE IF NOT EXISTS combos (
  id            INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  combo_name    VARCHAR(60)   NOT NULL,
  combo_price   DECIMAL(12,2) NOT NULL,
  actual_price  DECIMAL(12,2) NOT NULL DEFAULT 0,
  gst_pct       DECIMAL(5,2)  NOT NULL DEFAULT 0,
  valid_from    DATE          NULL,
  valid_to      DATE          NULL,
  image_url     VARCHAR(255)  NULL,
  status        TINYINT(1)    NOT NULL DEFAULT 1,
  is_deleted    TINYINT(1)    NOT NULL DEFAULT 0,
  created_by    INT           NULL,
  created_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by    INT           NULL,
  updated_at    DATETIME      NULL,
  active_name   VARCHAR(60)   GENERATED ALWAYS AS (IF(is_deleted = 0, combo_name, NULL)) VIRTUAL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_combos_name (active_name),
  KEY ix_combos_status (status),
  KEY ix_combos_validity (valid_from, valid_to)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS combo_items (
  id        INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  combo_id  INT UNSIGNED  NOT NULL,
  item_id   INT UNSIGNED  NOT NULL,
  qty       DECIMAL(12,3) NOT NULL,
  price     DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT 'Item selling price when the combo was saved',
  PRIMARY KEY (id),
  UNIQUE KEY uq_combo_items (combo_id, item_id),
  KEY ix_combo_items_item (item_id),
  CONSTRAINT fk_combo_items_combo FOREIGN KEY (combo_id) REFERENCES combos (id) ON DELETE CASCADE,
  CONSTRAINT fk_combo_items_item  FOREIGN KEY (item_id)  REFERENCES items (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
