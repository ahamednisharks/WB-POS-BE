-- Till movements: bill payments, refunds and cash paid out (supplier / salary).
CREATE TABLE IF NOT EXISTS transactions (
  id                 INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  txn_no             VARCHAR(20)   NOT NULL,
  txn_date           DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  txn_type           ENUM('PAYMENT','REFUND','CASH_OUT') NOT NULL,
  payment_mode       ENUM('CASH','UPI','CARD','BANK','CHEQUE') NOT NULL,
  amount             DECIMAL(12,2) NOT NULL,
  bill_id            INT UNSIGNED  NULL,
  purchase_entry_id  INT UNSIGNED  NULL,
  salary_payment_id  INT UNSIGNED  NULL,
  reference_no       VARCHAR(50)   NULL,
  remarks            VARCHAR(200)  NULL,
  user_id            INT UNSIGNED  NOT NULL,
  created_at         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_transactions_no (txn_no),
  KEY ix_transactions_date (txn_date),
  KEY ix_transactions_user_date (user_id, txn_date),
  KEY ix_transactions_type_mode (txn_type, payment_mode),
  KEY ix_transactions_bill (bill_id),
  KEY ix_transactions_pe (purchase_entry_id),
  KEY ix_transactions_salary (salary_payment_id),
  CONSTRAINT fk_transactions_bill   FOREIGN KEY (bill_id)           REFERENCES bills (id),
  CONSTRAINT fk_transactions_pe     FOREIGN KEY (purchase_entry_id) REFERENCES purchase_entries (id),
  CONSTRAINT fk_transactions_salary FOREIGN KEY (salary_payment_id) REFERENCES salary_payments (id),
  CONSTRAINT fk_transactions_user   FOREIGN KEY (user_id)           REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS day_closings (
  id             INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  close_date     DATE          NOT NULL,
  cashier_id     INT UNSIGNED  NOT NULL,
  opening_cash   DECIMAL(12,2) NOT NULL DEFAULT 0,
  cash_sales     DECIMAL(12,2) NOT NULL DEFAULT 0,
  cash_refunds   DECIMAL(12,2) NOT NULL DEFAULT 0,
  cash_outs      DECIMAL(12,2) NOT NULL DEFAULT 0,
  expected_cash  DECIMAL(12,2) NOT NULL DEFAULT 0,
  counted_cash   DECIMAL(12,2) NOT NULL DEFAULT 0,
  difference     DECIMAL(12,2) NOT NULL DEFAULT 0,
  remarks        VARCHAR(255)  NULL,
  created_by     INT           NULL,
  created_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by     INT           NULL,
  updated_at     DATETIME      NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_day_closings (close_date, cashier_id),
  KEY ix_day_closings_cashier (cashier_id),
  CONSTRAINT fk_day_closings_cashier FOREIGN KEY (cashier_id) REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS stock_ledger (
  id             INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  item_id        INT UNSIGNED  NOT NULL,
  txn_date       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  txn_type       ENUM('OPENING','PURCHASE','SALE','SALE_CANCEL','PE_EDIT','ADJUST') NOT NULL,
  ref_table      VARCHAR(40)   NULL,
  ref_id         INT UNSIGNED  NULL,
  qty_in         DECIMAL(12,3) NOT NULL DEFAULT 0,
  qty_out        DECIMAL(12,3) NOT NULL DEFAULT 0,
  balance_after  DECIMAL(12,3) NOT NULL,
  created_by     INT           NULL,
  PRIMARY KEY (id),
  KEY ix_stock_ledger_item_date (item_id, txn_date),
  KEY ix_stock_ledger_ref (ref_table, ref_id),
  CONSTRAINT fk_stock_ledger_item FOREIGN KEY (item_id) REFERENCES items (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS audit_log (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id     INT          NULL,
  action      VARCHAR(40)  NOT NULL,
  table_name  VARCHAR(40)  NOT NULL,
  record_id   INT UNSIGNED NULL,
  old_json    JSON         NULL,
  new_json    JSON         NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_audit_log_table (table_name, record_id),
  KEY ix_audit_log_date (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
