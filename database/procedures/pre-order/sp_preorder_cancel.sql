-- sp_preorder_cancel
-- Purpose : ADMIN cancels a BOOKED / READY pre-order and decides how much of the amount paid goes back to the
--           customer - all of it, part of it or nothing. A refund is recorded as one REFUND till transaction in the
--           chosen mode (so day close takes cash refunds out of the drawer); the rest is kept by the shop.
-- Params  : p_id, p_reason, p_refund_amount (0 .. paid), p_refund_mode (CASH|UPI|CARD, needed when refunding),
--           p_reference_no, p_user_id, p_role
-- Results : the pre-order, as sp_preorder_get
-- Errors  : 45000 validation / not open, 45403 not admin, 45404 not found
CREATE PROCEDURE sp_preorder_cancel(
  IN p_id            INT,
  IN p_reason        VARCHAR(200),
  IN p_refund_amount DECIMAL(12,2),
  IN p_refund_mode   VARCHAR(10),
  IN p_reference_no  VARCHAR(50),
  IN p_user_id       INT,
  IN p_role          VARCHAR(10)
)
BEGIN
  DECLARE v_status   VARCHAR(10) DEFAULT NULL;
  DECLARE v_order_no VARCHAR(20);
  DECLARE v_paid     DECIMAL(12,2) DEFAULT 0;
  DECLARE v_reason   VARCHAR(200) DEFAULT TRIM(IFNULL(p_reason, ''));
  DECLARE v_refund   DECIMAL(12,2) DEFAULT ROUND(IFNULL(p_refund_amount, 0), 2);
  DECLARE v_mode     VARCHAR(10) DEFAULT UPPER(TRIM(IFNULL(p_refund_mode, '')));
  DECLARE v_txn_no   VARCHAR(20);
  DECLARE v_msg      VARCHAR(128);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF IFNULL(p_role, '') <> 'ADMIN' THEN
    SIGNAL SQLSTATE '45403' SET MESSAGE_TEXT = 'Only Admin can cancel a pre-order';
  END IF;
  IF v_reason = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'reason::Cancel reason is required';
  END IF;
  IF v_refund < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'refundAmount::Refund cannot be negative';
  END IF;
  IF v_refund > 0 AND v_mode NOT IN ('CASH', 'UPI', 'CARD') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'refundMode::Select how the refund is paid';
  END IF;

  START TRANSACTION;

  SELECT order_status, order_no, paid_amount INTO v_status, v_order_no, v_paid
    FROM pre_orders WHERE id = p_id AND is_deleted = 0
     FOR UPDATE;

  IF v_status IS NULL THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Pre-order not found';
  END IF;
  IF v_status NOT IN ('BOOKED', 'READY') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The pre-order was already delivered or cancelled';
  END IF;
  IF v_refund > v_paid THEN
    SET v_msg = CONCAT('refundAmount::Refund cannot be more than the amount paid (', v_paid, ')');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  IF v_refund > 0 THEN
    CALL sp_util_next_number('TXN', v_txn_no);
    INSERT INTO transactions (txn_no, txn_date, txn_type, payment_mode, amount, pre_order_id, reference_no, remarks, user_id)
    VALUES (v_txn_no, NOW(), 'REFUND', v_mode, v_refund, p_id, NULLIF(TRIM(p_reference_no), ''),
            LEFT(CONCAT('Pre-order ', v_order_no, ' cancelled: ', v_reason), 200), p_user_id);
  END IF;

  UPDATE pre_orders
     SET order_status = 'CANCELLED', cancel_reason = v_reason, refund_amount = v_refund,
         cancelled_by = p_user_id, cancelled_at = NOW(), updated_by = p_user_id, updated_at = NOW()
   WHERE id = p_id;

  CALL sp_util_audit(p_user_id, 'CANCEL', 'pre_orders', p_id,
                     JSON_OBJECT('status', v_status, 'orderNo', v_order_no, 'paid', v_paid),
                     JSON_OBJECT('status', 'CANCELLED', 'reason', v_reason, 'refund', v_refund,
                                 'refundMode', NULLIF(v_mode, ''), 'kept', v_paid - v_refund));

  COMMIT;

  CALL sp_preorder_get(p_id);
END
