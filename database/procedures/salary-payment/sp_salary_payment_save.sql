-- sp_salary_payment_save
-- Purpose : Insert (p_id = 0) or update a monthly salary record. Gross is recomputed from the salary setup
--           (client value ignored); net = gross + bonus - advance deduction - other deductions (must be >= 0).
--           p_pay_status = 'PAID' also marks it paid (advance recovery + cash-out) in the same transaction.
-- Params  : p_id, p_employee_id, p_month, p_working_days, p_days_present, p_bonus, p_advance_deduction,
--           p_other_deduction, p_deduction_reason, p_pay_status (PENDING|PAID), p_payment_date, p_payment_mode, p_user_id
-- Results : (1) id, message
-- Errors  : 45000 validation, 45404 not found, 45409 salary already exists for the month
CREATE PROCEDURE sp_salary_payment_save(
  IN p_id                INT,
  IN p_employee_id       INT,
  IN p_month             CHAR(7),
  IN p_working_days      DECIMAL(5,1),
  IN p_days_present      DECIMAL(5,1),
  IN p_bonus             DECIMAL(12,2),
  IN p_advance_deduction DECIMAL(12,2),
  IN p_other_deduction   DECIMAL(12,2),
  IN p_deduction_reason  VARCHAR(200),
  IN p_pay_status        VARCHAR(10),
  IN p_payment_date      DATE,
  IN p_payment_mode      VARCHAR(10),
  IN p_user_id           INT
)
BEGIN
  DECLARE v_id       INT DEFAULT IFNULL(p_id, 0);
  DECLARE v_gross    DECIMAL(12,2);
  DECLARE v_setup_id INT;
  DECLARE v_bonus    DECIMAL(12,2) DEFAULT ROUND(GREATEST(IFNULL(p_bonus, 0), 0), 2);
  DECLARE v_adv      DECIMAL(12,2) DEFAULT ROUND(GREATEST(IFNULL(p_advance_deduction, 0), 0), 2);
  DECLARE v_other    DECIMAL(12,2) DEFAULT ROUND(GREATEST(IFNULL(p_other_deduction, 0), 0), 2);
  DECLARE v_net      DECIMAL(12,2);
  DECLARE v_pending  DECIMAL(12,2);
  DECLARE v_old      VARCHAR(10) DEFAULT NULL;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF NOT EXISTS (SELECT 1 FROM employees WHERE id = p_employee_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'employeeId::Employee not found';
  END IF;
  IF IFNULL(p_pay_status, 'PENDING') NOT IN ('PENDING', 'PAID') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'status::Status must be PENDING or PAID';
  END IF;

  IF v_id > 0 THEN
    SELECT pay_status INTO v_old FROM salary_payments WHERE id = v_id AND is_deleted = 0;
    IF v_old IS NULL THEN
      SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Salary payment not found';
    END IF;
    IF v_old = 'PAID' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Paid salary records cannot be edited';
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM salary_payments WHERE employee_id = p_employee_id AND pay_month = p_month
                                             AND id <> v_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45409' SET MESSAGE_TEXT = 'month::Salary for this employee and month already exists';
  END IF;

  CALL sp_salary_payment_compute(p_employee_id, p_month, p_working_days, p_days_present, v_gross, v_setup_id);

  IF v_other > 0 AND TRIM(IFNULL(p_deduction_reason, '')) = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'deductionReason::Reason is required for other deductions';
  END IF;

  SELECT IFNULL(SUM(amount - recovered_amount), 0) INTO v_pending
    FROM employee_advances WHERE employee_id = p_employee_id AND is_deleted = 0;
  IF v_adv > v_pending THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'advanceDeduction::Advance deduction cannot exceed the pending advance';
  END IF;

  SET v_net = v_gross + v_bonus - v_adv - v_other;
  IF v_net < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'otherDeductions::Deductions cannot be more than gross salary plus bonus';
  END IF;

  START TRANSACTION;

  IF v_id = 0 THEN
    INSERT INTO salary_payments (employee_id, pay_month, working_days, days_present, gross_salary, bonus,
                                 advance_deduction, other_deduction, deduction_reason, net_salary, pay_status, created_by)
    VALUES (p_employee_id, p_month, p_working_days, p_days_present, v_gross, v_bonus, v_adv, v_other,
            NULLIF(TRIM(p_deduction_reason), ''), v_net, 'PENDING', p_user_id);
    SET v_id = LAST_INSERT_ID();
  ELSE
    UPDATE salary_payments
       SET employee_id = p_employee_id, pay_month = p_month, working_days = p_working_days, days_present = p_days_present,
           gross_salary = v_gross, bonus = v_bonus, advance_deduction = v_adv, other_deduction = v_other,
           deduction_reason = NULLIF(TRIM(p_deduction_reason), ''), net_salary = v_net,
           updated_by = p_user_id, updated_at = NOW()
     WHERE id = v_id;
  END IF;

  IF p_pay_status = 'PAID' THEN
    CALL sp_salary_payment_post_paid(v_id, p_payment_date, p_payment_mode, p_user_id);
  END IF;

  COMMIT;

  SELECT v_id AS id, IF(p_pay_status = 'PAID', 'Salary saved and marked as paid', 'Salary saved successfully') AS message;
END
