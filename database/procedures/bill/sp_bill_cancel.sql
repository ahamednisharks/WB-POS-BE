-- sp_bill_cancel
-- Purpose : Cancels a bill. COMPLETED bills (ADMIN only): stock is returned exactly as it was deducted
--           (SALE_CANCEL from the bill's stock_ledger rows), a REFUND transaction is written per payment,
--           customer totals are reduced, history + audit written. HELD bills (owner or admin) are simply closed.
-- Params  : p_id, p_reason, p_remarks, p_user_id, p_role
-- Results : (1) id, message
-- Errors  : 45000 reason missing / already cancelled, 45403 cashier cancelling a completed bill, 45404 not found
CREATE PROCEDURE sp_bill_cancel(
  IN p_id      INT,
  IN p_reason  VARCHAR(200),
  IN p_remarks VARCHAR(200),
  IN p_user_id INT,
  IN p_role    VARCHAR(10)
)
BEGIN
  DECLARE v_status   VARCHAR(10) DEFAULT NULL;
  DECLARE v_cashier  INT;
  DECLARE v_bill_no  VARCHAR(20);
  DECLARE v_customer INT;
  DECLARE v_grand    DECIMAL(12,2);
  DECLARE v_reason   VARCHAR(200) DEFAULT TRIM(IFNULL(p_reason, ''));
  DECLARE v_note     VARCHAR(200);
  DECLARE v_i        INT DEFAULT 0;
  DECLARE v_n        INT DEFAULT 0;
  DECLARE v_item     INT;
  DECLARE v_qty      DECIMAL(12,3);
  DECLARE v_txn_no   VARCHAR(20);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF v_reason = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'reason::Cancel reason is required';
  END IF;
  SET v_note = LEFT(IF(TRIM(IFNULL(p_remarks, '')) = '', v_reason, CONCAT(v_reason, ' - ', TRIM(p_remarks))), 200);

  START TRANSACTION;

  SELECT bill_status, cashier_id, bill_no, customer_id, grand_total
    INTO v_status, v_cashier, v_bill_no, v_customer, v_grand
    FROM bills WHERE id = p_id AND is_deleted = 0 FOR UPDATE;

  IF v_status IS NULL OR (p_role = 'CASHIER' AND v_cashier <> p_user_id) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Bill not found';
  END IF;
  IF v_status = 'CANCELLED' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bill is already cancelled';
  END IF;
  IF v_status = 'COMPLETED' AND IFNULL(p_role, '') <> 'ADMIN' THEN
    SIGNAL SQLSTATE '45403' SET MESSAGE_TEXT = 'Only Admin can cancel a completed bill';
  END IF;

  IF v_status = 'COMPLETED' THEN
    DROP TEMPORARY TABLE IF EXISTS tmp_cancel_stock;
    CREATE TEMPORARY TABLE tmp_cancel_stock (
      seq INT NOT NULL AUTO_INCREMENT PRIMARY KEY, item_id INT NOT NULL, qty DECIMAL(12,3) NOT NULL
    ) ENGINE=MEMORY;
    INSERT INTO tmp_cancel_stock (item_id, qty)
    SELECT item_id, SUM(qty_out) - SUM(qty_in)
      FROM stock_ledger
     WHERE ref_table = 'bills' AND ref_id = p_id AND txn_type IN ('SALE', 'SALE_CANCEL')
     GROUP BY item_id
    HAVING SUM(qty_out) - SUM(qty_in) > 0
     ORDER BY item_id;

    SELECT COUNT(*) INTO v_n FROM tmp_cancel_stock;
    SET v_i = 1;
    WHILE v_i <= v_n DO
      SELECT item_id, qty INTO v_item, v_qty FROM tmp_cancel_stock WHERE seq = v_i;
      CALL sp_util_stock_post(v_item, 'SALE_CANCEL', 'bills', p_id, v_qty, 0, p_user_id);
      SET v_i = v_i + 1;
    END WHILE;

    DROP TEMPORARY TABLE IF EXISTS tmp_cancel_pay;
    CREATE TEMPORARY TABLE tmp_cancel_pay (
      seq INT NOT NULL AUTO_INCREMENT PRIMARY KEY, payment_mode VARCHAR(10) NOT NULL,
      amount DECIMAL(12,2) NOT NULL, reference_no VARCHAR(50) NULL
    ) ENGINE=MEMORY;
    INSERT INTO tmp_cancel_pay (payment_mode, amount, reference_no)
    SELECT payment_mode, amount, reference_no FROM bill_payments WHERE bill_id = p_id ORDER BY id;

    SELECT COUNT(*) INTO v_n FROM tmp_cancel_pay;
    SET v_i = 1;
    WHILE v_i <= v_n DO
      CALL sp_util_next_number('TXN', v_txn_no);
      INSERT INTO transactions (txn_no, txn_date, txn_type, payment_mode, amount, bill_id, reference_no, remarks, user_id)
      SELECT v_txn_no, NOW(), 'REFUND', payment_mode, amount, p_id, reference_no, LEFT(CONCAT('Refund: ', v_note), 200), p_user_id
        FROM tmp_cancel_pay WHERE seq = v_i;
      SET v_i = v_i + 1;
    END WHILE;

    IF v_customer IS NOT NULL THEN
      UPDATE customers
         SET total_spent = GREATEST(total_spent - v_grand, 0), visit_count = GREATEST(visit_count - 1, 0), updated_at = NOW()
       WHERE id = v_customer;
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_cancel_stock, tmp_cancel_pay;
  END IF;

  UPDATE bills
     SET bill_status = 'CANCELLED', cancel_reason = v_note, cancelled_by = p_user_id, cancelled_at = NOW(),
         updated_by = p_user_id, updated_at = NOW()
   WHERE id = p_id;

  INSERT INTO bill_status_history (bill_id, from_status, to_status, remarks, changed_by)
  VALUES (p_id, v_status, 'CANCELLED', v_note, p_user_id);

  CALL sp_util_audit(p_user_id, 'CANCEL', 'bills', p_id,
                     JSON_OBJECT('status', v_status, 'billNo', v_bill_no, 'grandTotal', v_grand),
                     JSON_OBJECT('status', 'CANCELLED', 'reason', v_note));

  COMMIT;

  SELECT p_id AS id, IF(v_status = 'COMPLETED', CONCAT('Bill ', v_bill_no, ' cancelled and refunded'), 'Held bill cancelled') AS message;
END
