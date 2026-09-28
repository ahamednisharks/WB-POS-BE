-- sp_bill_save
-- Purpose : Creates a bill (p_id = 0) or updates / completes a HELD bill (p_id > 0). All prices, GST and totals are
--           recomputed from master data (client prices ignored):
--             line_amount = qty x rate; bill discount (AMOUNT | PERCENT of sub total) is apportioned to lines by
--             line_amount, the last line takes the rounding remainder; price-includes-GST lines back-calculate tax,
--             others add it; CGST = round(GST / 2), SGST = GST - CGST; grand total rounded to the rupee.
--           CASHIER discount is capped by shop_settings.cashier_max_discount_pct.
--           HELD: no bill number (H-<id>), no payments, no stock.  COMPLETED: B2627-000123 number, payments must equal
--           the grand total exactly, a PAYMENT transaction per payment, stock posted (combos per component) and the
--           customer upserted.  A repeated p_client_ref returns the existing bill (offline idempotency).
-- Params  : p_id, p_client_ref (UUID), p_device_id, p_status (HELD|COMPLETED), p_customer_mobile, p_customer_name,
--           p_discount_type (AMOUNT|PERCENT), p_discount_value,
--           p_items JSON [{ "itemId": 1, "qty": 2 } | { "comboId": 3, "qty": 1 }],
--           p_payments JSON [{ "mode": "CASH", "amount": 250, "referenceNo": null, "cashReceived": 500 }],
--           p_user_id, p_role
-- Results : the saved bill, as sp_bill_get: (1) header, (2) lines, (3) payments, (4) status history
-- Errors  : 45000 validation, 45403 discount above cashier limit, 45404 bill / item not found
CREATE PROCEDURE sp_bill_save(
  IN p_id              INT,
  IN p_client_ref      VARCHAR(36),
  IN p_device_id       VARCHAR(50),
  IN p_status          VARCHAR(10),
  IN p_customer_mobile VARCHAR(10),
  IN p_customer_name   VARCHAR(80),
  IN p_discount_type   VARCHAR(10),
  IN p_discount_value  DECIMAL(12,2),
  IN p_items           JSON,
  IN p_payments        JSON,
  IN p_user_id         INT,
  IN p_role            VARCHAR(10)
)
proc: BEGIN
  DECLARE v_id          INT DEFAULT IFNULL(p_id, 0);
  DECLARE v_existing    INT DEFAULT NULL;
  DECLARE v_old_status  VARCHAR(10) DEFAULT NULL;
  DECLARE v_old_cashier INT DEFAULT NULL;
  DECLARE v_lines       INT DEFAULT 0;
  DECLARE v_last        INT DEFAULT 0;
  DECLARE v_bad_line    INT DEFAULT NULL;
  DECLARE v_bad_name    VARCHAR(100) DEFAULT NULL;
  DECLARE v_sub         DECIMAL(12,2) DEFAULT 0;
  DECLARE v_disc_type   VARCHAR(10) DEFAULT IF(p_discount_type = 'PERCENT', 'PERCENT', 'AMOUNT');
  DECLARE v_disc_value  DECIMAL(12,2) DEFAULT GREATEST(IFNULL(p_discount_value, 0), 0);
  DECLARE v_discount    DECIMAL(12,2) DEFAULT 0;
  DECLARE v_alloc       DECIMAL(12,2) DEFAULT 0;
  DECLARE v_max_pct     DECIMAL(5,2) DEFAULT 10;
  DECLARE v_taxable     DECIMAL(12,2) DEFAULT 0;
  DECLARE v_gst         DECIMAL(12,2) DEFAULT 0;
  DECLARE v_cgst        DECIMAL(12,2) DEFAULT 0;
  DECLARE v_sgst        DECIMAL(12,2) DEFAULT 0;
  DECLARE v_exact       DECIMAL(12,2) DEFAULT 0;
  DECLARE v_grand       DECIMAL(12,2) DEFAULT 0;
  DECLARE v_round       DECIMAL(12,2) DEFAULT 0;
  DECLARE v_pay_count   INT DEFAULT 0;
  DECLARE v_paid        DECIMAL(12,2) DEFAULT 0;
  DECLARE v_bad_mode    INT DEFAULT 0;
  DECLARE v_short_cash  INT DEFAULT 0;
  DECLARE v_pay_mode    VARCHAR(10) DEFAULT NULL;
  DECLARE v_bill_no     VARCHAR(20) DEFAULT NULL;
  DECLARE v_txn_no      VARCHAR(20);
  DECLARE v_customer_id INT DEFAULT NULL;
  DECLARE v_mobile      VARCHAR(10) DEFAULT NULLIF(TRIM(IFNULL(p_customer_mobile, '')), '');
  DECLARE v_name        VARCHAR(80) DEFAULT NULLIF(TRIM(IFNULL(p_customer_name, '')), '');
  DECLARE v_client_ref  VARCHAR(36) DEFAULT NULLIF(TRIM(IFNULL(p_client_ref, '')), '');
  DECLARE v_i           INT DEFAULT 0;
  DECLARE v_n           INT DEFAULT 0;
  DECLARE v_item        INT;
  DECLARE v_qty         DECIMAL(12,3);
  DECLARE v_msg         VARCHAR(128);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  -- Offline sync: the same device bill sent twice returns the first one.
  IF v_id = 0 AND v_client_ref IS NOT NULL THEN
    SELECT MAX(id) INTO v_existing FROM bills WHERE client_ref = v_client_ref;
    IF v_existing IS NOT NULL THEN
      CALL sp_bill_get(v_existing, p_user_id, p_role);
      LEAVE proc;
    END IF;
  END IF;

  IF IFNULL(p_status, '') NOT IN ('HELD', 'COMPLETED') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'status::Status must be HELD or COMPLETED';
  END IF;
  IF v_mobile IS NOT NULL AND v_mobile NOT REGEXP '^[6-9][0-9]{9}$' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'customerMobile::Customer mobile must be a valid 10-digit number';
  END IF;

  IF v_id > 0 THEN
    SELECT bill_status, cashier_id INTO v_old_status, v_old_cashier FROM bills WHERE id = v_id AND is_deleted = 0;
    IF v_old_status IS NULL OR (p_role = 'CASHIER' AND v_old_cashier <> p_user_id) THEN
      SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Bill not found';
    END IF;
    IF v_old_status <> 'HELD' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The held bill was already completed or cancelled';
    END IF;
  END IF;

  -- ---------------------------------------------------------------- lines
  DROP TEMPORARY TABLE IF EXISTS tmp_bill_lines;
  CREATE TEMPORARY TABLE tmp_bill_lines (
    line_no            INT NOT NULL PRIMARY KEY,
    item_id            INT NULL,
    combo_id           INT NULL,
    qty                DECIMAL(12,3) NULL,
    item_code          VARCHAR(20) NULL,
    item_name          VARCHAR(100) NULL,
    unit_code          VARCHAR(10) NULL,
    allow_decimal      TINYINT NOT NULL DEFAULT 0,
    rate               DECIMAL(12,2) NOT NULL DEFAULT 0,
    gst_pct            DECIMAL(5,2) NOT NULL DEFAULT 0,
    price_includes_gst TINYINT NOT NULL DEFAULT 1,
    line_amount        DECIMAL(12,2) NOT NULL DEFAULT 0,
    discount_share     DECIMAL(12,2) NOT NULL DEFAULT 0,
    taxable_amount     DECIMAL(12,2) NOT NULL DEFAULT 0,
    gst_amount         DECIMAL(12,2) NOT NULL DEFAULT 0,
    cgst               DECIMAL(12,2) NOT NULL DEFAULT 0,
    sgst               DECIMAL(12,2) NOT NULL DEFAULT 0,
    line_total         DECIMAL(12,2) NOT NULL DEFAULT 0,
    valid              TINYINT NOT NULL DEFAULT 0
  ) ENGINE=MEMORY;

  INSERT INTO tmp_bill_lines (line_no, item_id, combo_id, qty)
  SELECT jt.line_no, jt.item_id, jt.combo_id, ROUND(jt.qty, 3)
    FROM JSON_TABLE(IFNULL(p_items, JSON_ARRAY()), '$[*]' COLUMNS (
           line_no  FOR ORDINALITY,
           item_id  INT           PATH '$.itemId'  NULL ON EMPTY,
           combo_id INT           PATH '$.comboId' NULL ON EMPTY,
           qty      DECIMAL(12,3) PATH '$.qty'     NULL ON EMPTY
         )) AS jt;

  SELECT COUNT(*), IFNULL(MAX(line_no), 0) INTO v_lines, v_last FROM tmp_bill_lines;
  IF v_lines = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::Add at least one item to the bill';
  END IF;

  SELECT MIN(line_no) INTO v_bad_line FROM tmp_bill_lines WHERE (item_id IS NULL) = (combo_id IS NULL);
  IF v_bad_line IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::Each bill line needs either an item or a combo';
  END IF;
  SELECT MIN(line_no) INTO v_bad_line FROM tmp_bill_lines WHERE IFNULL(qty, 0) <= 0;
  IF v_bad_line IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::Quantity must be greater than 0';
  END IF;

  UPDATE tmp_bill_lines t
    JOIN items i ON i.id = t.item_id
    JOIN units u ON u.id = i.unit_id
     SET t.item_code = i.item_code, t.item_name = i.item_name, t.unit_code = u.short_code,
         t.allow_decimal = u.allow_decimal, t.rate = i.selling_price, t.gst_pct = i.gst_pct,
         t.price_includes_gst = i.price_includes_gst,
         t.valid = IF(i.is_deleted = 0 AND i.status = 1 AND i.item_type IN ('SALE', 'BOTH'), 1, 0)
   WHERE t.item_id IS NOT NULL;

  UPDATE tmp_bill_lines t
    JOIN combos c ON c.id = t.combo_id
     SET t.item_code = 'COMBO', t.item_name = c.combo_name, t.unit_code = 'PCS', t.allow_decimal = 0,
         t.rate = c.combo_price, t.gst_pct = c.gst_pct, t.price_includes_gst = 1,
         t.valid = IF(c.is_deleted = 0 AND c.status = 1
                      AND (c.valid_from IS NULL OR c.valid_from <= CURDATE())
                      AND (c.valid_to IS NULL OR c.valid_to >= CURDATE()), 1, 0)
   WHERE t.combo_id IS NOT NULL;

  SET v_bad_line = NULL;
  SELECT line_no, IFNULL(item_name, 'An item') INTO v_bad_line, v_bad_name
    FROM tmp_bill_lines WHERE valid = 0 ORDER BY line_no LIMIT 1;
  IF v_bad_line IS NOT NULL THEN
    SET v_msg = LEFT(CONCAT('items::', v_bad_name, ' is not available for sale'), 128);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  SELECT line_no, item_name INTO v_bad_line, v_bad_name
    FROM tmp_bill_lines WHERE allow_decimal = 0 AND qty <> FLOOR(qty) ORDER BY line_no LIMIT 1;
  IF v_bad_line IS NOT NULL THEN
    SET v_msg = LEFT(CONCAT('items::', v_bad_name, ' quantity must be a whole number'), 128);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  -- ----------------------------------------------------------- totals
  UPDATE tmp_bill_lines SET line_amount = ROUND(qty * rate, 2);
  SELECT IFNULL(SUM(line_amount), 0) INTO v_sub FROM tmp_bill_lines;

  SET v_discount = CASE
    WHEN v_disc_value <= 0 OR v_sub <= 0 THEN 0
    WHEN v_disc_type = 'PERCENT' THEN ROUND(v_sub * LEAST(v_disc_value, 100) / 100, 2)
    ELSE v_disc_value
  END;
  SET v_discount = LEAST(v_discount, v_sub);

  SELECT IFNULL(MAX(cashier_max_discount_pct), 10) INTO v_max_pct FROM shop_settings WHERE id = 1;
  IF p_role = 'CASHIER' AND v_discount > ROUND(v_sub * v_max_pct / 100, 2) THEN
    SET v_msg = CONCAT('discountValue::Cashiers can give at most ', TRIM(TRAILING '.' FROM TRIM(TRAILING '0' FROM v_max_pct)), '% discount');
    SIGNAL SQLSTATE '45403' SET MESSAGE_TEXT = v_msg;
  END IF;

  UPDATE tmp_bill_lines SET discount_share = IF(v_sub > 0, ROUND(v_discount * line_amount / v_sub, 2), 0);
  SELECT IFNULL(SUM(discount_share), 0) INTO v_alloc FROM tmp_bill_lines;
  UPDATE tmp_bill_lines SET discount_share = discount_share + (v_discount - v_alloc) WHERE line_no = v_last;

  UPDATE tmp_bill_lines
     SET taxable_amount = IF(price_includes_gst = 1,
                             ROUND((line_amount - discount_share) * 100 / (100 + gst_pct), 2),
                             line_amount - discount_share);
  UPDATE tmp_bill_lines
     SET gst_amount = IF(price_includes_gst = 1,
                         (line_amount - discount_share) - taxable_amount,
                         ROUND(taxable_amount * gst_pct / 100, 2));
  UPDATE tmp_bill_lines
     SET cgst = ROUND(gst_amount / 2, 2),
         sgst = gst_amount - ROUND(gst_amount / 2, 2),
         line_total = taxable_amount + gst_amount;

  SELECT IFNULL(SUM(taxable_amount), 0), IFNULL(SUM(gst_amount), 0) INTO v_taxable, v_gst FROM tmp_bill_lines;
  SET v_cgst  = ROUND(v_gst / 2, 2);
  SET v_sgst  = v_gst - v_cgst;
  SET v_exact = v_taxable + v_gst;
  SET v_grand = ROUND(v_exact, 0);
  SET v_round = v_grand - v_exact;

  -- --------------------------------------------------------- payments
  DROP TEMPORARY TABLE IF EXISTS tmp_bill_pay;
  CREATE TEMPORARY TABLE tmp_bill_pay (
    pay_no          INT NOT NULL PRIMARY KEY,
    payment_mode    VARCHAR(10) NULL,
    amount          DECIMAL(12,2) NOT NULL,
    reference_no    VARCHAR(50) NULL,
    cash_received   DECIMAL(12,2) NULL,
    change_returned DECIMAL(12,2) NULL
  ) ENGINE=MEMORY;

  IF p_status = 'COMPLETED' THEN
    INSERT INTO tmp_bill_pay (pay_no, payment_mode, amount, reference_no, cash_received)
    SELECT jt.pay_no, UPPER(jt.pay_mode), ROUND(jt.amount, 2), NULLIF(TRIM(jt.reference_no), ''), jt.cash_received
      FROM JSON_TABLE(IFNULL(p_payments, JSON_ARRAY()), '$[*]' COLUMNS (
             pay_no        FOR ORDINALITY,
             pay_mode      VARCHAR(10)   PATH '$.mode'         NULL ON EMPTY,
             amount        DECIMAL(12,2) PATH '$.amount'       NULL ON EMPTY,
             reference_no  VARCHAR(50)   PATH '$.referenceNo'  NULL ON EMPTY,
             cash_received DECIMAL(12,2) PATH '$.cashReceived' NULL ON EMPTY
           )) AS jt
     WHERE IFNULL(jt.amount, 0) > 0;

    SELECT COUNT(*), IFNULL(SUM(amount), 0),
           IFNULL(SUM(IFNULL(payment_mode, '') NOT IN ('CASH', 'UPI', 'CARD')), 0),
           IFNULL(SUM(payment_mode = 'CASH' AND cash_received IS NOT NULL AND cash_received < amount), 0),
           IF(COUNT(DISTINCT payment_mode) > 1, 'SPLIT', MIN(payment_mode))
      INTO v_pay_count, v_paid, v_bad_mode, v_short_cash, v_pay_mode
      FROM tmp_bill_pay;

    IF v_pay_count = 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'payments::Payment details are required';
    END IF;
    IF v_bad_mode > 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'payments::Payment mode must be CASH, UPI or CARD';
    END IF;
    IF v_paid <> v_grand THEN
      SET v_msg = CONCAT('payments::Payment total does not match bill total (paid ', v_paid, ', bill ', v_grand, ')');
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    IF v_short_cash > 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'payments::Cash received cannot be less than the cash amount';
    END IF;

    UPDATE tmp_bill_pay
       SET cash_received   = IF(payment_mode = 'CASH', IFNULL(cash_received, amount), NULL),
           change_returned = IF(payment_mode = 'CASH', IFNULL(cash_received, amount) - amount, NULL);
  END IF;

  -- ------------------------------------------------------------ write
  START TRANSACTION;

  IF v_id > 0 THEN
    SELECT bill_status INTO v_old_status FROM bills WHERE id = v_id FOR UPDATE;
    IF v_old_status <> 'HELD' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The held bill was already completed or cancelled';
    END IF;
    DELETE FROM bill_items WHERE bill_id = v_id;
  END IF;

  IF p_status = 'COMPLETED' THEN
    CALL sp_util_next_number('BILL', v_bill_no);
    IF v_mobile IS NOT NULL THEN
      INSERT INTO customers (mobile, customer_name, total_spent, visit_count, last_visit_at)
      VALUES (v_mobile, v_name, v_grand, 1, NOW()) AS nc
      ON DUPLICATE KEY UPDATE customer_name = COALESCE(nc.customer_name, customers.customer_name),
                              total_spent   = customers.total_spent + nc.total_spent,
                              visit_count   = customers.visit_count + 1,
                              last_visit_at = nc.last_visit_at,
                              updated_at    = NOW();
      SELECT id INTO v_customer_id FROM customers WHERE mobile = v_mobile;
    END IF;
  ELSEIF v_mobile IS NOT NULL THEN
    SELECT MAX(id) INTO v_customer_id FROM customers WHERE mobile = v_mobile;
  END IF;

  IF v_id = 0 THEN
    INSERT INTO bills (bill_no, bill_date, client_ref, device_id, customer_id, customer_mobile, customer_name, item_count,
                       sub_total, discount_type, discount_value, discount_amount, taxable_amount, cgst, sgst, round_off,
                       grand_total, payment_mode, bill_status, cashier_id, created_by)
    VALUES (v_bill_no, NOW(), v_client_ref, p_device_id, v_customer_id, v_mobile, v_name, v_lines,
            v_sub, v_disc_type, v_disc_value, v_discount, v_taxable, v_cgst, v_sgst, v_round,
            v_grand, v_pay_mode, p_status, p_user_id, p_user_id);
    SET v_id = LAST_INSERT_ID();
    IF p_status = 'HELD' THEN
      UPDATE bills SET bill_no = CONCAT('H-', v_id) WHERE id = v_id;
    END IF;
    INSERT INTO bill_status_history (bill_id, from_status, to_status, remarks, changed_by)
    VALUES (v_id, NULL, p_status, NULL, p_user_id);
  ELSE
    UPDATE bills
       SET bill_no = IFNULL(v_bill_no, bill_no), bill_date = NOW(),
           client_ref = IFNULL(client_ref, v_client_ref), device_id = IFNULL(p_device_id, device_id),
           customer_id = v_customer_id, customer_mobile = v_mobile, customer_name = v_name, item_count = v_lines,
           sub_total = v_sub, discount_type = v_disc_type, discount_value = v_disc_value, discount_amount = v_discount,
           taxable_amount = v_taxable, cgst = v_cgst, sgst = v_sgst, round_off = v_round, grand_total = v_grand,
           payment_mode = v_pay_mode, bill_status = p_status,
           cashier_id = IF(p_status = 'COMPLETED', p_user_id, cashier_id),
           updated_by = p_user_id, updated_at = NOW()
     WHERE id = v_id;
    INSERT INTO bill_status_history (bill_id, from_status, to_status, remarks, changed_by)
    VALUES (v_id, 'HELD', p_status, IF(p_status = 'COMPLETED', 'Resumed from hold', 'Updated'), p_user_id);
  END IF;

  INSERT INTO bill_items (bill_id, line_no, item_id, combo_id, item_code, item_name, unit_code, allow_decimal, qty, rate,
                          gst_pct, price_includes_gst, line_amount, discount_share, taxable_amount, cgst, sgst, line_total)
  SELECT v_id, line_no, item_id, combo_id, item_code, item_name, unit_code, allow_decimal, qty, rate,
         gst_pct, price_includes_gst, line_amount, discount_share, taxable_amount, cgst, sgst, line_total
    FROM tmp_bill_lines
   ORDER BY line_no;

  IF p_status = 'COMPLETED' THEN
    INSERT INTO bill_payments (bill_id, payment_mode, amount, reference_no, cash_received, change_returned)
    SELECT v_id, payment_mode, amount, reference_no, cash_received, change_returned FROM tmp_bill_pay ORDER BY pay_no;

    SELECT IFNULL(MAX(pay_no), 0) INTO v_n FROM tmp_bill_pay;
    SET v_i = 1;
    WHILE v_i <= v_n DO
      IF EXISTS (SELECT 1 FROM tmp_bill_pay WHERE pay_no = v_i) THEN
        CALL sp_util_next_number('TXN', v_txn_no);
        INSERT INTO transactions (txn_no, txn_date, txn_type, payment_mode, amount, bill_id, reference_no, remarks, user_id)
        SELECT v_txn_no, NOW(), 'PAYMENT', payment_mode, amount, v_id, reference_no, CONCAT('Bill ', v_bill_no), p_user_id
          FROM tmp_bill_pay WHERE pay_no = v_i;
      END IF;
      SET v_i = v_i + 1;
    END WHILE;

    -- Stock: plain items directly, combos per component x combo qty; one post per item in id order (lock order).
    DROP TEMPORARY TABLE IF EXISTS tmp_bill_stock_raw;
    CREATE TEMPORARY TABLE tmp_bill_stock_raw (item_id INT NOT NULL, qty DECIMAL(12,3) NOT NULL) ENGINE=MEMORY;
    INSERT INTO tmp_bill_stock_raw (item_id, qty)
    SELECT item_id, qty FROM tmp_bill_lines WHERE item_id IS NOT NULL;
    INSERT INTO tmp_bill_stock_raw (item_id, qty)
    SELECT ci.item_id, ROUND(ci.qty * t.qty, 3)
      FROM tmp_bill_lines t JOIN combo_items ci ON ci.combo_id = t.combo_id
     WHERE t.combo_id IS NOT NULL;

    DROP TEMPORARY TABLE IF EXISTS tmp_bill_stock;
    CREATE TEMPORARY TABLE tmp_bill_stock (
      seq INT NOT NULL AUTO_INCREMENT PRIMARY KEY, item_id INT NOT NULL, qty DECIMAL(12,3) NOT NULL
    ) ENGINE=MEMORY;
    INSERT INTO tmp_bill_stock (item_id, qty)
    SELECT item_id, SUM(qty) FROM tmp_bill_stock_raw GROUP BY item_id ORDER BY item_id;

    SELECT COUNT(*) INTO v_n FROM tmp_bill_stock;
    SET v_i = 1;
    WHILE v_i <= v_n DO
      SELECT item_id, qty INTO v_item, v_qty FROM tmp_bill_stock WHERE seq = v_i;
      CALL sp_util_stock_post(v_item, 'SALE', 'bills', v_id, 0, v_qty, p_user_id);
      SET v_i = v_i + 1;
    END WHILE;
  END IF;

  COMMIT;

  DROP TEMPORARY TABLE IF EXISTS tmp_bill_lines, tmp_bill_pay, tmp_bill_stock_raw, tmp_bill_stock;

  CALL sp_bill_get(v_id, p_user_id, p_role);
END
