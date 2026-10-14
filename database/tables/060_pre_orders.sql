-- Pre-orders (custom cakes etc.): booked with any number of advance payments, delivered later as a normal bill.
-- Money columns are denormalised by sp_preorder_save so the list screen never aggregates.
CREATE TABLE IF NOT EXISTS pre_orders (
  id                INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  order_no          VARCHAR(20)   NOT NULL COMMENT 'WB-PRE-2026-0001',
  order_date        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  customer_id       INT UNSIGNED  NULL,
  customer_mobile   VARCHAR(10)   NOT NULL,
  customer_name     VARCHAR(80)   NOT NULL,
  alt_mobile        VARCHAR(10)   NULL,
  delivery_at       DATETIME      NOT NULL,
  delivery_type     ENUM('PICKUP','HOME') NOT NULL DEFAULT 'PICKUP',
  delivery_address  VARCHAR(255)  NULL,
  delivery_charge   DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT 'Not taxed',
  item_count        INT           NOT NULL DEFAULT 0,
  sub_total         DECIMAL(12,2) NOT NULL DEFAULT 0,
  discount_amount   DECIMAL(12,2) NOT NULL DEFAULT 0,
  taxable_amount    DECIMAL(12,2) NOT NULL DEFAULT 0,
  cgst              DECIMAL(12,2) NOT NULL DEFAULT 0,
  sgst              DECIMAL(12,2) NOT NULL DEFAULT 0,
  round_off         DECIMAL(12,2) NOT NULL DEFAULT 0,
  grand_total       DECIMAL(12,2) NOT NULL DEFAULT 0,
  paid_amount       DECIMAL(12,2) NOT NULL DEFAULT 0 COMMENT 'Sum of pre_order_payments',
  order_status      ENUM('BOOKED','READY','DELIVERED','CANCELLED') NOT NULL DEFAULT 'BOOKED',
  bill_id           INT UNSIGNED  NULL COMMENT 'Bill created on delivery',
  ready_at          DATETIME      NULL,
  delivered_at      DATETIME      NULL,
  cancel_reason     VARCHAR(200)  NULL,
  refund_amount     DECIMAL(12,2) NULL,
  cancelled_by      INT UNSIGNED  NULL,
  cancelled_at      DATETIME      NULL,
  booked_by         INT UNSIGNED  NOT NULL,
  is_deleted        TINYINT(1)    NOT NULL DEFAULT 0,
  created_by        INT           NULL,
  created_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by        INT           NULL,
  updated_at        DATETIME      NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_pre_orders_no (order_no),
  KEY ix_pre_orders_status_delivery (order_status, delivery_at),
  KEY ix_pre_orders_delivery (delivery_at),
  KEY ix_pre_orders_mobile (customer_mobile),
  KEY ix_pre_orders_customer (customer_id),
  KEY ix_pre_orders_bill (bill_id),
  CONSTRAINT fk_pre_orders_customer  FOREIGN KEY (customer_id) REFERENCES customers (id),
  CONSTRAINT fk_pre_orders_bill      FOREIGN KEY (bill_id)     REFERENCES bills (id),
  CONSTRAINT fk_pre_orders_booked_by FOREIGN KEY (booked_by)   REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- master_rate = Item Master price when the line was first booked ("Actual Price"), kept on later edits;
-- rate = the agreed price for this order ("Item Price"), editable by cashiers.
CREATE TABLE IF NOT EXISTS pre_order_items (
  id                  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  pre_order_id        INT UNSIGNED  NOT NULL,
  line_no             INT           NOT NULL,
  item_id             INT UNSIGNED  NOT NULL,
  item_code           VARCHAR(20)   NULL,
  item_name           VARCHAR(100)  NOT NULL,
  category_name       VARCHAR(50)   NULL,
  unit_code           VARCHAR(10)   NULL,
  allow_decimal       TINYINT(1)    NOT NULL DEFAULT 0,
  qty                 DECIMAL(12,3) NOT NULL,
  master_rate         DECIMAL(12,2) NOT NULL,
  rate                DECIMAL(12,2) NOT NULL,
  gst_pct             DECIMAL(5,2)  NOT NULL,
  price_includes_gst  TINYINT(1)    NOT NULL,
  line_amount         DECIMAL(12,2) NOT NULL,
  discount_share      DECIMAL(12,2) NOT NULL DEFAULT 0,
  taxable_amount      DECIMAL(12,2) NOT NULL,
  cgst                DECIMAL(12,2) NOT NULL,
  sgst                DECIMAL(12,2) NOT NULL,
  line_total          DECIMAL(12,2) NOT NULL,
  notes               VARCHAR(255)  NULL COMMENT 'Cake message, eggless, flavour ...',
  design_url          VARCHAR(255)  NULL COMMENT 'Reference photo under /uploads/images',
  PRIMARY KEY (id),
  KEY ix_pre_order_items_order (pre_order_id),
  KEY ix_pre_order_items_item (item_id),
  CONSTRAINT fk_pre_order_items_order FOREIGN KEY (pre_order_id) REFERENCES pre_orders (id),
  CONSTRAINT fk_pre_order_items_item  FOREIGN KEY (item_id)      REFERENCES items (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Every payment taken before delivery; each one also has a PAYMENT row in transactions (txn_id).
CREATE TABLE IF NOT EXISTS pre_order_payments (
  id            INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  pre_order_id  INT UNSIGNED  NOT NULL,
  payment_mode  ENUM('CASH','UPI','CARD') NOT NULL,
  amount        DECIMAL(12,2) NOT NULL,
  reference_no  VARCHAR(50)   NULL,
  txn_id        INT UNSIGNED  NULL,
  paid_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  received_by   INT UNSIGNED  NOT NULL,
  PRIMARY KEY (id),
  KEY ix_pre_order_payments_order (pre_order_id),
  KEY ix_pre_order_payments_txn (txn_id),
  CONSTRAINT fk_pre_order_payments_order FOREIGN KEY (pre_order_id) REFERENCES pre_orders (id),
  CONSTRAINT fk_pre_order_payments_txn   FOREIGN KEY (txn_id)       REFERENCES transactions (id),
  CONSTRAINT fk_pre_order_payments_user  FOREIGN KEY (received_by)  REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Columns on existing tables. MySQL has no ADD COLUMN IF NOT EXISTS, so each change is guarded by an
-- information_schema check to keep `npm run migrate pre_orders` re-runnable.

-- transactions.pre_order_id: advance payments / refunds of a pre-order (PAYMENT / REFUND rows).
SET @ddl = IF((SELECT COUNT(*) FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'transactions' AND COLUMN_NAME = 'pre_order_id') = 0,
              'ALTER TABLE transactions
                 ADD COLUMN pre_order_id INT UNSIGNED NULL AFTER salary_payment_id,
                 ADD KEY ix_transactions_pre_order (pre_order_id),
                 ADD CONSTRAINT fk_transactions_pre_order FOREIGN KEY (pre_order_id) REFERENCES pre_orders (id)',
              'DO 0');
PREPARE ddl FROM @ddl;
EXECUTE ddl;
DEALLOCATE PREPARE ddl;

-- bills.delivery_charge: a delivered pre-order's charge, part of grand_total, not taxed (0 for counter bills).
SET @ddl = IF((SELECT COUNT(*) FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bills' AND COLUMN_NAME = 'delivery_charge') = 0,
              'ALTER TABLE bills ADD COLUMN delivery_charge DECIMAL(12,2) NOT NULL DEFAULT 0 AFTER sgst',
              'DO 0');
PREPARE ddl FROM @ddl;
EXECUTE ddl;
DEALLOCATE PREPARE ddl;

-- bill_payments.is_advance: payment taken on the pre-order before delivery (its transaction already exists).
SET @ddl = IF((SELECT COUNT(*) FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bill_payments' AND COLUMN_NAME = 'is_advance') = 0,
              'ALTER TABLE bill_payments ADD COLUMN is_advance TINYINT(1) NOT NULL DEFAULT 0 AFTER change_returned',
              'DO 0');
PREPARE ddl FROM @ddl;
EXECUTE ddl;
DEALLOCATE PREPARE ddl;
