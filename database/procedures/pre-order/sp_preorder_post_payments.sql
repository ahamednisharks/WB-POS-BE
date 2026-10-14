-- sp_preorder_post_payments
-- Purpose : Records payments taken on a pre-order before delivery: a pre_order_payments row and a PAYMENT till
--           transaction per payment (so day close counts the cash on the day it is received), then adds them to
--           pre_orders.paid_amount. Zero-amount entries are skipped. The total paid can never exceed the grand total.
--           No transaction control: call it inside the caller's transaction after locking the pre_orders row.
-- Params  : p_pre_order_id, p_payments JSON [{ "mode": "CASH", "amount": 400, "referenceNo": null }], p_user_id,
--           OUT p_count (payments recorded)
-- Results : none
-- Errors  : 45000 validation
CREATE PROCEDURE sp_preorder_post_payments(
  IN  p_pre_order_id INT,
  IN  p_payments     JSON,
  IN  p_user_id      INT,
  OUT p_count        INT
)
BEGIN
  DECLARE v_order_no VARCHAR(20);
  DECLARE v_grand    DECIMAL(12,2) DEFAULT 0;
  DECLARE v_paid     DECIMAL(12,2) DEFAULT 0;
  DECLARE v_new      DECIMAL(12,2) DEFAULT 0;
  DECLARE v_bad_mode INT DEFAULT 0;
  DECLARE v_i        INT DEFAULT 1;
  DECLARE v_n        INT DEFAULT 0;
  DECLARE v_txn_no   VARCHAR(20);
  DECLARE v_txn_id   INT;
  DECLARE v_msg      VARCHAR(128);

  DROP TEMPORARY TABLE IF EXISTS tmp_preorder_pay;
  CREATE TEMPORARY TABLE tmp_preorder_pay (
    pay_no       INT NOT NULL PRIMARY KEY,
    payment_mode VARCHAR(10) NULL,
    amount       DECIMAL(12,2) NOT NULL,
    reference_no VARCHAR(50) NULL
  );

  INSERT INTO tmp_preorder_pay (pay_no, payment_mode, amount, reference_no)
  SELECT jt.pay_no, UPPER(jt.pay_mode), ROUND(jt.amount, 2), NULLIF(TRIM(jt.reference_no), '')
    FROM JSON_TABLE(IFNULL(p_payments, JSON_ARRAY()), '$[*]' COLUMNS (
           pay_no       FOR ORDINALITY,
           pay_mode     VARCHAR(10)   PATH '$.mode'        NULL ON EMPTY,
           amount       DECIMAL(12,2) PATH '$.amount'      NULL ON EMPTY,
           reference_no VARCHAR(50)   PATH '$.referenceNo' NULL ON EMPTY
         )) AS jt
   WHERE IFNULL(jt.amount, 0) > 0;

  SELECT COUNT(*), IFNULL(SUM(amount), 0), IFNULL(SUM(IFNULL(payment_mode, '') NOT IN ('CASH', 'UPI', 'CARD')), 0),
         IFNULL(MAX(pay_no), 0)
    INTO p_count, v_new, v_bad_mode, v_n
    FROM tmp_preorder_pay;

  IF p_count > 0 THEN
    IF v_bad_mode > 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'payments::Payment mode must be CASH, UPI or CARD';
    END IF;

    SELECT order_no, grand_total, paid_amount INTO v_order_no, v_grand, v_paid FROM pre_orders WHERE id = p_pre_order_id;
    IF v_paid + v_new > v_grand THEN
      SET v_msg = CONCAT('payments::Payment cannot be more than the balance due of ', v_grand - v_paid);
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    WHILE v_i <= v_n DO
      IF EXISTS (SELECT 1 FROM tmp_preorder_pay WHERE pay_no = v_i) THEN
        CALL sp_util_next_number('TXN', v_txn_no);
        INSERT INTO transactions (txn_no, txn_date, txn_type, payment_mode, amount, pre_order_id, reference_no, remarks, user_id)
        SELECT v_txn_no, NOW(), 'PAYMENT', payment_mode, amount, p_pre_order_id, reference_no,
               CONCAT('Pre-order advance ', v_order_no), p_user_id
          FROM tmp_preorder_pay WHERE pay_no = v_i;
        SET v_txn_id = LAST_INSERT_ID();

        INSERT INTO pre_order_payments (pre_order_id, payment_mode, amount, reference_no, txn_id, paid_at, received_by)
        SELECT p_pre_order_id, payment_mode, amount, reference_no, v_txn_id, NOW(), p_user_id
          FROM tmp_preorder_pay WHERE pay_no = v_i;
      END IF;
      SET v_i = v_i + 1;
    END WHILE;

    UPDATE pre_orders SET paid_amount = paid_amount + v_new WHERE id = p_pre_order_id;
  END IF;

  DROP TEMPORARY TABLE IF EXISTS tmp_preorder_pay;
END
