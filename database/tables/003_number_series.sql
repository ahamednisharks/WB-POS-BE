CREATE TABLE IF NOT EXISTS number_series (
  series_key  VARCHAR(20)  NOT NULL,
  prefix      VARCHAR(12)  NOT NULL,
  next_no     INT UNSIGNED NOT NULL DEFAULT 1,
  pad_length  TINYINT      NOT NULL DEFAULT 4,
  updated_at  DATETIME     NULL,
  PRIMARY KEY (series_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
