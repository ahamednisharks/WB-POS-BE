-- sp_salary_payment_compute
-- Purpose : Shared gross-salary rule (no result set; used by calculate and save).
--           MONTHLY: (basic + allowances) x days_present / working_days.  DAILY: basic x days_present.  Rounded to 2.
-- Params  : p_employee_id, p_month 'YYYY-MM', p_working_days, p_days_present, OUT p_gross, OUT p_setup_id
-- Results : none
-- Errors  : 45000 invalid month / days, no salary setup for the month
CREATE PROCEDURE sp_salary_payment_compute(
  IN  p_employee_id  INT,
  IN  p_month        CHAR(7),
  IN  p_working_days DECIMAL(5,1),
  IN  p_days_present DECIMAL(5,1),
  OUT p_gross        DECIMAL(12,2),
  OUT p_setup_id     INT
)
BEGIN
  DECLARE v_type      VARCHAR(10) DEFAULT NULL;
  DECLARE v_basic     DECIMAL(12,2);
  DECLARE v_allow     DECIMAL(12,2);
  DECLARE v_month_end DATE;
  DECLARE v_msg       VARCHAR(128);

  IF IFNULL(p_month, '') NOT REGEXP '^[0-9]{4}-(0[1-9]|1[0-2])$' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'month::Month must be YYYY-MM';
  END IF;
  IF IFNULL(p_working_days, 0) < 1 OR p_working_days > 31 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'workingDays::Working days must be between 1 and 31';
  END IF;
  IF IFNULL(p_days_present, -1) < 0 OR p_days_present > p_working_days THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'daysPresent::Days present must be between 0 and the working days';
  END IF;

  SET v_month_end = LAST_DAY(STR_TO_DATE(CONCAT(p_month, '-01'), '%Y-%m-%d'));

  SELECT s.id, s.salary_type, s.basic_salary, s.allowances
    INTO p_setup_id, v_type, v_basic, v_allow
    FROM salary_setups s
   WHERE s.employee_id = p_employee_id AND s.is_deleted = 0 AND s.effective_from <= v_month_end
   ORDER BY s.effective_from DESC, s.id DESC
   LIMIT 1;

  IF v_type IS NULL THEN
    SET v_msg = CONCAT('employeeId::No salary setup found for this employee for ', p_month);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  IF v_type = 'MONTHLY' THEN
    SET p_gross = ROUND((v_basic + v_allow) * p_days_present / p_working_days, 2);
  ELSE
    SET p_gross = ROUND(v_basic * p_days_present, 2);
  END IF;
END
