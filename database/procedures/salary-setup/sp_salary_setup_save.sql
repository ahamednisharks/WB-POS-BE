-- sp_salary_setup_save
-- Purpose : Insert (p_id = 0) or update a salary setup. One setup per employee per effective date.
-- Params  : p_id, p_employee_id, p_salary_type (MONTHLY|DAILY), p_basic_salary (per month / per day), p_allowances,
--           p_effective_from, p_user_id
-- Results : (1) id, message
-- Errors  : 45000 validation, 45404 not found, 45409 duplicate effective date
CREATE PROCEDURE sp_salary_setup_save(
  IN p_id             INT,
  IN p_employee_id    INT,
  IN p_salary_type    VARCHAR(10),
  IN p_basic_salary   DECIMAL(12,2),
  IN p_allowances     DECIMAL(12,2),
  IN p_effective_from DATE,
  IN p_user_id        INT
)
BEGIN
  DECLARE v_id INT DEFAULT IFNULL(p_id, 0);

  IF NOT EXISTS (SELECT 1 FROM employees WHERE id = p_employee_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'employeeId::Employee not found';
  END IF;
  IF IFNULL(p_salary_type, '') NOT IN ('MONTHLY', 'DAILY') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'salaryType::Salary type must be MONTHLY or DAILY';
  END IF;
  IF IFNULL(p_basic_salary, 0) <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'basicSalary::Basic salary must be greater than 0';
  END IF;
  IF IFNULL(p_allowances, 0) < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'allowances::Allowances cannot be negative';
  END IF;
  IF p_effective_from IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'effectiveFrom::Effective from date is required';
  END IF;
  IF EXISTS (SELECT 1 FROM salary_setups WHERE employee_id = p_employee_id AND effective_from = p_effective_from
                                           AND id <> v_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45409' SET MESSAGE_TEXT = 'effectiveFrom::This employee already has a salary setup from this date';
  END IF;

  IF v_id = 0 THEN
    INSERT INTO salary_setups (employee_id, salary_type, basic_salary, allowances, effective_from, created_by)
    VALUES (p_employee_id, p_salary_type, ROUND(p_basic_salary, 2), ROUND(IFNULL(p_allowances, 0), 2), p_effective_from, p_user_id);
    SET v_id = LAST_INSERT_ID();
  ELSE
    IF NOT EXISTS (SELECT 1 FROM salary_setups WHERE id = v_id AND is_deleted = 0) THEN
      SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Salary setup not found';
    END IF;
    UPDATE salary_setups
       SET employee_id = p_employee_id, salary_type = p_salary_type, basic_salary = ROUND(p_basic_salary, 2),
           allowances = ROUND(IFNULL(p_allowances, 0), 2), effective_from = p_effective_from,
           updated_by = p_user_id, updated_at = NOW()
     WHERE id = v_id;
  END IF;

  SELECT v_id AS id, 'Salary setup saved successfully' AS message;
END
