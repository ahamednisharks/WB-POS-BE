-- sp_pe_add_payment
-- Purpose : Pays (part of) a purchase entry's balance: updates paid / balance / status, the supplier balance and,
--           for cash, records a CASH_OUT till transaction.
-- Params  : p_pe_id, p_amount, p_mode (CASH|BANK|UPI|CHEQUE), p_payment_date, p_reference_no, p_user_id
-- Results : (1) id, message
-- Errors  : 45000 validation (amount > balance ...), 45404 not found
CREATE PROCEDURE sp_pe_add_payment(
  IN p_pe_id        INT,
  IN p_amount       DECIMAL(12,2),
  IN p_mode         VARCHAR(10),
  IN p_payment_date DATE,
  IN p_reference_no VARCHAR(50),
  IN p_user_id      INT
)
BEGIN
  DECLARE v_balance  DECIMAL(12,2) DEFAULT NULL;
  DECLARE v_grand    DECIMAL(12,2);
  DECLARE v_paid     DECIMAL(12,2);
  DECLARE v_supplier INT;
  DECLARE v_pe_no    VARCHAR(20);
  DECLARE v_name     VARCHAR(80);
  DECLARE v_amount   DECIMAL(12,2) DEFAULT ROUND(IFNULL(p_amount, 0), 2);
  DECLARE v_txn_no   VARCHAR(20);
  DECLARE v_msg      VARCHAR(128);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF v_amount <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'amount::Amount must be greater than 0';
  END IF;
  IF IFNULL(p_mode, '') NOT IN ('CASH', 'BANK', 'UPI', 'CHEQUE') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'mode::Payment mode must be CASH, BANK, UPI or CHEQUE';
  END IF;
  IF p_payment_date IS NULL OR p_payment_date > CURDATE() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'date::Payment date is required and cannot be in the future';
  END IF;

  START TRANSACTION;

  SELECT pe.balance, pe.grand_total, pe.paid_amount, pe.supplier_id, pe.pe_no, s.supplier_name
    INTO v_balance, v_grand, v_paid, v_supplier, v_pe_no, v_name
    FROM purchase_entries pe JOIN suppliers s ON s.id = pe.supplier_id
   WHERE pe.id = p_pe_id AND pe.is_deleted = 0
     FOR UPDATE;

  IF v_balance IS NULL THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Purchase entry not found';
  END IF;
  IF v_amount > v_balance THEN
    SET v_msg = CONCAT('amount::Amount cannot exceed the balance of ', v_balance);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  INSERT INTO supplier_payments (supplier_id, pe_id, payment_date, amount, payment_mode, reference_no, created_by)
  VALUES (v_supplier, p_pe_id, p_payment_date, v_amount, p_mode, NULLIF(TRIM(p_reference_no), ''), p_user_id);

  SET v_paid = v_paid + v_amount;
  UPDATE purchase_entries
     SET paid_amount = v_paid, balance = v_grand - v_paid,
         payment_status = IF(v_paid >= v_grand, 'PAID', 'PARTIAL'),
         updated_by = p_user_id, updated_at = NOW()
   WHERE id = p_pe_id;

  UPDATE suppliers SET current_balance = current_balance - v_amount WHERE id = v_supplier;

  IF p_mode = 'CASH' THEN
    CALL sp_util_next_number('TXN', v_txn_no);
    INSERT INTO transactions (txn_no, txn_date, txn_type, payment_mode, amount, purchase_entry_id, reference_no, remarks, user_id)
    VALUES (v_txn_no, NOW(), 'CASH_OUT', 'CASH', v_amount, p_pe_id, NULLIF(TRIM(p_reference_no), ''),
            LEFT(CONCAT('Supplier payment - ', v_name, ' (', v_pe_no, ')'), 200), p_user_id);
  END IF;

  COMMIT;

  SELECT p_pe_id AS id, CONCAT('Payment of ', v_amount, ' recorded') AS message;
END
