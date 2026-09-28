-- sp_advance_save
-- Purpose : Insert (p_id = 0) or update a salary advance. An edited amount cannot go below what was already recovered.
-- Params  : p_id, p_employee_id, p_advance_date, p_amount, p_remarks, p_user_id
-- Results : (1) id, message
-- Errors  : 45000 validation, 45404 not found
CREATE PROCEDURE sp_advance_save(
  IN p_id           INT,
  IN p_employee_id  INT,
  IN p_advance_date DATE,
  IN p_amount       DECIMAL(12,2),
  IN p_remarks      VARCHAR(200),
  IN p_user_id      INT
)
BEGIN
  DECLARE v_id        INT DEFAULT IFNULL(p_id, 0);
  DECLARE v_recovered DECIMAL(12,2);

  IF NOT EXISTS (SELECT 1 FROM employees WHERE id = p_employee_id AND is_deleted = 0 AND emp_status = 'ACTIVE') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'employeeId::Select an active employee';
  END IF;
  IF p_advance_date IS NULL OR p_advance_date > CURDATE() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'advanceDate::Advance date is required and cannot be in the future';
  END IF;
  IF IFNULL(p_amount, 0) <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'amount::Amount must be greater than 0';
  END IF;

  IF v_id = 0 THEN
    INSERT INTO employee_advances (employee_id, advance_date, amount, remarks, created_by)
    VALUES (p_employee_id, p_advance_date, ROUND(p_amount, 2), NULLIF(TRIM(p_remarks), ''), p_user_id);
    SET v_id = LAST_INSERT_ID();
  ELSE
    SELECT recovered_amount INTO v_recovered FROM employee_advances WHERE id = v_id AND is_deleted = 0;
    IF v_recovered IS NULL THEN
      SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Advance not found';
    END IF;
    IF p_amount < v_recovered THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'amount::Amount cannot be less than the amount already recovered';
    END IF;
    UPDATE employee_advances
       SET employee_id = p_employee_id, advance_date = p_advance_date, amount = ROUND(p_amount, 2),
           remarks = NULLIF(TRIM(p_remarks), ''), updated_by = p_user_id, updated_at = NOW()
     WHERE id = v_id;
  END IF;

  SELECT v_id AS id, 'Advance saved successfully' AS message;
END
