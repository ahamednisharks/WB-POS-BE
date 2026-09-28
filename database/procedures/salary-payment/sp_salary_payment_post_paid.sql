-- sp_salary_payment_post_paid
-- Purpose : Internal step shared by save / mark-paid (no result set; call inside the caller's transaction):
--           marks the row PAID, recovers the advance deduction from open advances oldest first,
--           and records a CASH_OUT till transaction when paid in cash.
-- Params  : p_id, p_payment_date, p_payment_mode (CASH|BANK|UPI), p_user_id
-- Results : none
-- Errors  : 45000 validation / already paid / advance changed, 45404 not found
CREATE PROCEDURE sp_salary_payment_post_paid(
  IN p_id           INT,
  IN p_payment_date DATE,
  IN p_payment_mode VARCHAR(10),
  IN p_user_id      INT
)
BEGIN
  DECLARE v_status   VARCHAR(10) DEFAULT NULL;
  DECLARE v_emp      INT;
  DECLARE v_month    CHAR(7);
  DECLARE v_net      DECIMAL(12,2);
  DECLARE v_deduct   DECIMAL(12,2);
  DECLARE v_pending  DECIMAL(12,2);
  DECLARE v_name     VARCHAR(80);
  DECLARE v_txn_no   VARCHAR(20);

  SELECT p.pay_status, p.employee_id, p.pay_month, p.net_salary, p.advance_deduction, e.full_name
    INTO v_status, v_emp, v_month, v_net, v_deduct, v_name
    FROM salary_payments p
    JOIN employees e ON e.id = p.employee_id
   WHERE p.id = p_id AND p.is_deleted = 0
     FOR UPDATE;

  IF v_status IS NULL THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Salary payment not found';
  END IF;
  IF v_status = 'PAID' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This salary is already marked as paid';
  END IF;
  IF p_payment_date IS NULL OR p_payment_date > CURDATE() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'paymentDate::Payment date is required and cannot be in the future';
  END IF;
  IF IFNULL(p_payment_mode, '') NOT IN ('CASH', 'BANK', 'UPI') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'paymentMode::Payment mode must be CASH, BANK or UPI';
  END IF;

  IF v_deduct > 0 THEN
    SELECT IFNULL(SUM(amount - recovered_amount), 0) INTO v_pending
      FROM employee_advances
     WHERE employee_id = v_emp AND is_deleted = 0
       FOR UPDATE;
    IF v_deduct > v_pending THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'advanceDeduction::Advance deduction is more than the pending advance';
    END IF;

    -- Oldest advance first: each one absorbs what is left of the deduction after the older ones.
    UPDATE employee_advances a
      JOIN (SELECT id, amount - recovered_amount AS open_amt,
                   SUM(amount - recovered_amount) OVER (ORDER BY advance_date, id) AS running
              FROM employee_advances
             WHERE employee_id = v_emp AND is_deleted = 0 AND amount > recovered_amount) x ON x.id = a.id
       SET a.recovered_amount = a.recovered_amount + GREATEST(0, LEAST(x.open_amt, v_deduct - (x.running - x.open_amt))),
           a.updated_by = p_user_id, a.updated_at = NOW()
     WHERE v_deduct - (x.running - x.open_amt) > 0;
  END IF;

  UPDATE salary_payments
     SET pay_status = 'PAID', payment_date = p_payment_date, payment_mode = p_payment_mode,
         updated_by = p_user_id, updated_at = NOW()
   WHERE id = p_id;

  IF p_payment_mode = 'CASH' AND v_net > 0 THEN
    CALL sp_util_next_number('TXN', v_txn_no);
    INSERT INTO transactions (txn_no, txn_date, txn_type, payment_mode, amount, salary_payment_id, remarks, user_id)
    VALUES (v_txn_no, NOW(), 'CASH_OUT', 'CASH', v_net, p_id,
            LEFT(CONCAT('Salary - ', v_name, ' (', DATE_FORMAT(STR_TO_DATE(CONCAT(v_month, '-01'), '%Y-%m-%d'), '%b %Y'), ')'), 200),
            p_user_id);
  END IF;
END
