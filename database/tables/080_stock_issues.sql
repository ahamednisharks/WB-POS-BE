-- Stock issues: raw material taken out of the warehouse (sent to production, wastage, expired, damaged, other).
-- One line per item per issue; every line posts stock OUT (stock_ledger ISSUE) at the item's last purchase rate.
-- Cancel and same-day edit reverse the lines (ISSUE_CANCEL). item_count / total_value are kept up to date by
-- sp_stock_issue_save so the list screen never aggregates.
CREATE TABLE IF NOT EXISTS stock_issues (
  id             INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  issue_no       VARCHAR(20)   NOT NULL COMMENT 'SI2627-0001 (number series STI)',
  issue_date     DATE          NOT NULL,
  remarks        VARCHAR(200)  NULL,
  item_count     INT           NOT NULL DEFAULT 0,
  total_value    DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT 'Sum of line amounts at the last purchase rate',
  issue_status   ENUM('POSTED','CANCELLED') NOT NULL DEFAULT 'POSTED',
  issued_by      INT UNSIGNED  NOT NULL COMMENT 'User who created it (owner for the same-day edit rule)',
  cancel_reason  VARCHAR(200)  NULL,
  cancelled_by   INT UNSIGNED  NULL,
  cancelled_at   DATETIME      NULL,
  created_by     INT           NULL,
  created_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by     INT           NULL,
  updated_at     DATETIME      NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_stock_issues_no (issue_no),
  KEY ix_stock_issues_date (issue_date),
  KEY ix_stock_issues_status_date (issue_status, issue_date),
  KEY ix_stock_issues_user (issued_by),
  CONSTRAINT fk_stock_issues_user FOREIGN KEY (issued_by) REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS stock_issue_items (
  id        INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  si_id     INT UNSIGNED  NOT NULL,
  line_no   INT           NOT NULL,
  item_id   INT UNSIGNED  NOT NULL,
  qty       DECIMAL(12,3) NOT NULL,
  reason    ENUM('PRODUCTION','WASTAGE','EXPIRED','DAMAGED','OTHER') NOT NULL DEFAULT 'PRODUCTION',
  rate      DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT 'items.purchase_price when posted',
  amount    DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT 'qty x rate',
  remarks   VARCHAR(200)  NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_stock_issue_items_item (si_id, item_id),
  KEY ix_stock_issue_items_item (item_id),
  KEY ix_stock_issue_items_reason (reason),
  CONSTRAINT fk_stock_issue_items_si   FOREIGN KEY (si_id)   REFERENCES stock_issues (id),
  CONSTRAINT fk_stock_issue_items_item FOREIGN KEY (item_id) REFERENCES items (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- stock_ledger.txn_type gains ISSUE / ISSUE_CANCEL (stock issues) and PRODUCTION (reserved for a later round).
-- Members are only appended, which MySQL 8 does as an instant metadata change (no table copy, no lock);
-- ALGORITHM=INSTANT makes the statement fail instead of copying the table if that is ever not possible.
-- Guarded so `npm run migrate stock_issues` can be re-run.
SET @ddl = IF((SELECT COUNT(*) FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'stock_ledger' AND COLUMN_NAME = 'txn_type'
                  AND COLUMN_TYPE NOT LIKE '%''ISSUE''%') = 1,
              'ALTER TABLE stock_ledger MODIFY COLUMN txn_type ENUM(''OPENING'',''PURCHASE'',''SALE'',''SALE_CANCEL'',''PE_EDIT'',''ADJUST'',''ISSUE'',''ISSUE_CANCEL'',''PRODUCTION'') NOT NULL, ALGORITHM=INSTANT',
              'DO 0');
PREPARE ddl FROM @ddl;
EXECUTE ddl;
DEALLOCATE PREPARE ddl;
