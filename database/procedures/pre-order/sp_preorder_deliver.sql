-- sp_preorder_deliver
-- Purpose : Hands over a BOOKED / READY pre-order and generates its bill. The balance (grand total - paid) is
--           collected now: p_payments must add up to it exactly (empty when already fully paid). Creates a COMPLETED
--           bill (B2627-000123) from the order's lines at the agreed prices, with the booked delivery charge, discount
--           and round off. bill_payments = the earlier advances (is_advance = 1, their till transactions already
--           exist) + the balance payments (a PAYMENT transaction each, also listed on the pre-order). Stock is
--           deducted and the customer's visit totals are updated now. The pre-order becomes DELIVERED.
-- Params  : p_id, p_payments JSON [{ "mode": "CASH", "amount": 770, "referenceNo": null, "cashReceived": 800 }], p_user_id
-- Results : the pre-order, as sp_preorder_get
-- Errors  : 45000 validation / not open / balance mismatch, 45404 not found
CREATE PROCEDURE sp_preorder_deliver(IN p_id INT, IN p_payments JSON, IN p_user_id INT)
BEGIN
  DECLARE v_status      VARCHAR(10) DEFAULT NULL;
  DECLARE v_order_no    VARCHAR(20);
  DECLARE v_grand       DECIMAL(12,2) DEFAULT 0;
  DECLARE v_paid        DECIMAL(12,2) DEFAULT 0;
  DECLARE v_balance     DECIMAL(12,2) DEFAULT 0;
  DECLARE v_mobile      VARCHAR(10);
  DECLARE v_name        VARCHAR(80);
  DECLARE v_customer_id INT DEFAULT NULL;
  DECLARE v_pay_count   INT DEFAULT 0;
  DECLARE v_new         DECIMAL(12,2) DEFAULT 0;
  DECLARE v_bad_mode    INT DEFAULT 0;
  DECLARE v_short_cash  INT DEFAULT 0;
  DECLARE v_pay_mode    VARCHAR(10) DEFAULT NULL;
  DECLARE v_bill_id     INT;
  DECLARE v_bill_no     VARCHAR(20);
  DECLARE v_txn_no      VARCHAR(20);
  DECLARE v_txn_id      INT;
  DECLARE v_i           INT DEFAULT 1;
  DECLARE v_n           INT DEFAULT 0;
  DECLARE v_item        INT;
  DECLARE v_qty         DECIMAL(12,3);
  DECLARE v_msg         VARCHAR(128);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  -- ------------------------------------------------- balance payments
  DROP TEMPORARY TABLE IF EXISTS tmp_preorder_final_pay;
  CREATE TEMPORARY TABLE tmp_preorder_final_pay (
    pay_no          INT NOT NULL PRIMARY KEY,
    payment_mode    VARCHAR(10) NULL,
    amount          DECIMAL(12,2) NOT NULL,
    reference_no    VARCHAR(50) NULL,
    cash_received   DECIMAL(12,2) NULL,
    change_returned DECIMAL(12,2) NULL
  );

  INSERT INTO tmp_preorder_final_pay (pay_no, payment_mode, amount, reference_no, cash_received)
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
         IFNULL(MAX(pay_no), 0)
    INTO v_pay_count, v_new, v_bad_mode, v_short_cash, v_n
    FROM tmp_preorder_final_pay;

  IF v_bad_mode > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'payments::Payment mode must be CASH, UPI or CARD';
  END IF;
  IF v_short_cash > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'payments::Cash received cannot be less than the cash amount';
  END IF;

  UPDATE tmp_preorder_final_pay
     SET cash_received   = IF(payment_mode = 'CASH', IFNULL(cash_received, amount), NULL),
         change_returned = IF(payment_mode = 'CASH', IFNULL(cash_received, amount) - amount, NULL);

  -- ------------------------------------------------------------ write
  START TRANSACTION;

  SELECT order_status, order_no, grand_total, paid_amount, customer_mobile, customer_name
    INTO v_status, v_order_no, v_grand, v_paid, v_mobile, v_name
    FROM pre_orders WHERE id = p_id AND is_deleted = 0
     FOR UPDATE;

  IF v_status IS NULL THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Pre-order not found';
  END IF;
  IF v_status NOT IN ('BOOKED', 'READY') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The pre-order was already delivered or cancelled';
  END IF;

  SET v_balance = v_grand - v_paid;
  IF v_new <> v_balance THEN
    SET v_msg = CONCAT('payments::Collect exactly the balance due of ', v_balance, ' (entered ', v_new, ')');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  -- The visit is counted now, as for a counter bill.
  INSERT INTO customers (mobile, customer_name, total_spent, visit_count, last_visit_at)
  VALUES (v_mobile, v_name, v_grand, 1, NOW()) AS nc
  ON DUPLICATE KEY UPDATE customer_name = nc.customer_name,
                          total_spent   = customers.total_spent + nc.total_spent,
                          visit_count   = customers.visit_count + 1,
                          last_visit_at = nc.last_visit_at,
                          updated_at    = NOW();
  SELECT id INTO v_customer_id FROM customers WHERE mobile = v_mobile;

  SELECT IF(COUNT(DISTINCT m.mode) > 1, 'SPLIT', MIN(m.mode)) INTO v_pay_mode
    FROM (SELECT payment_mode AS mode FROM pre_order_payments WHERE pre_order_id = p_id
          UNION ALL
          SELECT payment_mode FROM tmp_preorder_final_pay) m;

  CALL sp_util_next_number('BILL', v_bill_no);
  INSERT INTO bills (bill_no, bill_date, customer_id, customer_mobile, customer_name, item_count, sub_total,
                     discount_type, discount_value, discount_amount, taxable_amount, cgst, sgst, delivery_charge,
                     round_off, grand_total, payment_mode, bill_status, cashier_id, created_by)
  SELECT v_bill_no, NOW(), v_customer_id, customer_mobile, customer_name, item_count, sub_total,
         'AMOUNT', discount_amount, discount_amount, taxable_amount, cgst, sgst, delivery_charge,
         round_off, grand_total, v_pay_mode, 'COMPLETED', p_user_id, p_user_id
    FROM pre_orders WHERE id = p_id;
  SET v_bill_id = LAST_INSERT_ID();

  INSERT INTO bill_status_history (bill_id, from_status, to_status, remarks, changed_by)
  VALUES (v_bill_id, NULL, 'COMPLETED', CONCAT('Delivered from pre-order ', v_order_no), p_user_id);

  INSERT INTO bill_items (bill_id, line_no, item_id, combo_id, item_code, item_name, unit_code, allow_decimal, qty, rate,
                          gst_pct, price_includes_gst, line_amount, discount_share, taxable_amount, cgst, sgst, line_total)
  SELECT v_bill_id, line_no, item_id, NULL, item_code, item_name, unit_code, allow_decimal, qty, rate,
         gst_pct, price_includes_gst, line_amount, discount_share, taxable_amount, cgst, sgst, line_total
    FROM pre_order_items
   WHERE pre_order_id = p_id
   ORDER BY line_no;

  -- Advances already have their till transactions; they only join the bill's payment list. No cash_received:
  -- the bill's "cash received / change" is about the cash handed over at delivery only.
  INSERT INTO bill_payments (bill_id, payment_mode, amount, reference_no, cash_received, change_returned, is_advance, created_at)
  SELECT v_bill_id, payment_mode, amount, reference_no, NULL, NULL, 1, paid_at
    FROM pre_order_payments
   WHERE pre_order_id = p_id
   ORDER BY id;

  WHILE v_i <= v_n DO
    IF EXISTS (SELECT 1 FROM tmp_preorder_final_pay WHERE pay_no = v_i) THEN
      CALL sp_util_next_number('TXN', v_txn_no);
      INSERT INTO transactions (txn_no, txn_date, txn_type, payment_mode, amount, bill_id, pre_order_id, reference_no, remarks, user_id)
      SELECT v_txn_no, NOW(), 'PAYMENT', payment_mode, amount, v_bill_id, p_id, reference_no,
             CONCAT('Bill ', v_bill_no, ' (pre-order ', v_order_no, ')'), p_user_id
        FROM tmp_preorder_final_pay WHERE pay_no = v_i;
      SET v_txn_id = LAST_INSERT_ID();

      INSERT INTO bill_payments (bill_id, payment_mode, amount, reference_no, cash_received, change_returned, is_advance)
      SELECT v_bill_id, payment_mode, amount, reference_no, cash_received, change_returned, 0
        FROM tmp_preorder_final_pay WHERE pay_no = v_i;

      INSERT INTO pre_order_payments (pre_order_id, payment_mode, amount, reference_no, txn_id, paid_at, received_by)
      SELECT p_id, payment_mode, amount, reference_no, v_txn_id, NOW(), p_user_id
        FROM tmp_preorder_final_pay WHERE pay_no = v_i;
    END IF;
    SET v_i = v_i + 1;
  END WHILE;

  -- Stock: one post per item in id order (lock order), as sp_bill_save does.
  DROP TEMPORARY TABLE IF EXISTS tmp_preorder_stock;
  CREATE TEMPORARY TABLE tmp_preorder_stock (
    seq INT NOT NULL AUTO_INCREMENT PRIMARY KEY, item_id INT NOT NULL, qty DECIMAL(12,3) NOT NULL
  );
  INSERT INTO tmp_preorder_stock (item_id, qty)
  SELECT item_id, SUM(qty) FROM pre_order_items WHERE pre_order_id = p_id GROUP BY item_id ORDER BY item_id;

  SELECT COUNT(*) INTO v_n FROM tmp_preorder_stock;
  SET v_i = 1;
  WHILE v_i <= v_n DO
    SELECT item_id, qty INTO v_item, v_qty FROM tmp_preorder_stock WHERE seq = v_i;
    CALL sp_util_stock_post(v_item, 'SALE', 'bills', v_bill_id, 0, v_qty, p_user_id);
    SET v_i = v_i + 1;
  END WHILE;

  UPDATE pre_orders
     SET order_status = 'DELIVERED', bill_id = v_bill_id, delivered_at = NOW(), paid_amount = paid_amount + v_new,
         customer_id = v_customer_id, updated_by = p_user_id, updated_at = NOW()
   WHERE id = p_id;

  COMMIT;

  DROP TEMPORARY TABLE IF EXISTS tmp_preorder_final_pay, tmp_preorder_stock;

  CALL sp_preorder_get(p_id);
END
