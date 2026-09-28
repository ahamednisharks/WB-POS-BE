CREATE TABLE IF NOT EXISTS shop_settings (
  id                          INT UNSIGNED  NOT NULL,
  shop_name                   VARCHAR(100)  NOT NULL,
  address                     VARCHAR(255)  NULL,
  state_code                  CHAR(2)       NOT NULL DEFAULT '33',
  gstin                       VARCHAR(15)   NULL,
  phone                       VARCHAR(20)   NULL,
  email                       VARCHAR(100)  NULL,
  logo_url                    VARCHAR(255)  NULL,
  upi_id                      VARCHAR(60)   NULL,
  receipt_footer              VARCHAR(255)  NULL,
  cashier_max_discount_pct    DECIMAL(5,2)  NOT NULL DEFAULT 10.00,
  allow_negative_stock        TINYINT(1)    NOT NULL DEFAULT 1,
  financial_year_start_month  TINYINT       NOT NULL DEFAULT 4,
  updated_by                  INT           NULL,
  updated_at                  DATETIME      NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_shop_settings_state FOREIGN KEY (state_code) REFERENCES states (state_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Exactly one row; the seed / settings screen fills in the details.
INSERT IGNORE INTO shop_settings (id, shop_name, state_code) VALUES (1, 'WB Bakery', '33');
