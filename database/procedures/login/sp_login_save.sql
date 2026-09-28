-- sp_login_save
-- Purpose : Create (p_id = 0) or update a login. Create needs an ACTIVE employee whose type can log in and who has
--           no login yet, plus a bcrypt hash made in Node. Update changes username / role / status only.
--           Admins cannot remove their own admin role or block themselves.
-- Params  : p_id, p_employee_id, p_username, p_password_hash (create only), p_role (ADMIN|CASHIER), p_status (1/0), p_user_id
-- Results : (1) id, message
-- Errors  : 45000 validation, 45404 not found, 45409 duplicate username / employee already has a login
CREATE PROCEDURE sp_login_save(
  IN p_id            INT,
  IN p_employee_id   INT,
  IN p_username      VARCHAR(30),
  IN p_password_hash VARCHAR(100),
  IN p_role          VARCHAR(10),
  IN p_status        TINYINT,
  IN p_user_id       INT
)
BEGIN
  DECLARE v_id        INT DEFAULT IFNULL(p_id, 0);
  DECLARE v_username  VARCHAR(30) DEFAULT TRIM(IFNULL(p_username, ''));
  DECLARE v_can_login INT DEFAULT NULL;
  DECLARE v_emp_state VARCHAR(10);
  DECLARE v_type_name VARCHAR(40);
  DECLARE v_msg       VARCHAR(128);

  IF v_username NOT REGEXP '^[^[:space:]]{3,30}$' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'username::Username must be 3-30 characters with no spaces';
  END IF;
  IF IFNULL(p_role, '') NOT IN ('ADMIN', 'CASHIER') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'role::Role must be ADMIN or CASHIER';
  END IF;
  IF EXISTS (SELECT 1 FROM users WHERE username = v_username AND id <> v_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45409' SET MESSAGE_TEXT = 'username::This username is already taken';
  END IF;

  IF v_id = 0 THEN
    SELECT t.can_login, e.emp_status, t.type_name INTO v_can_login, v_emp_state, v_type_name
      FROM employees e JOIN employee_types t ON t.id = e.employee_type_id
     WHERE e.id = p_employee_id AND e.is_deleted = 0;

    IF v_can_login IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'employeeId::Employee not found';
    END IF;
    IF v_can_login = 0 THEN
      SET v_msg = CONCAT('employeeId::', v_type_name, ' employees cannot have a login');
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    IF v_emp_state <> 'ACTIVE' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'employeeId::Resigned employees cannot have a login';
    END IF;
    IF EXISTS (SELECT 1 FROM users WHERE employee_id = p_employee_id AND is_deleted = 0) THEN
      SIGNAL SQLSTATE '45409' SET MESSAGE_TEXT = 'employeeId::This employee already has a login';
    END IF;
    IF IFNULL(p_password_hash, '') = '' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'password::Password is required';
    END IF;

    INSERT INTO users (employee_id, username, password_hash, role, status, created_by)
    VALUES (p_employee_id, v_username, p_password_hash, p_role, IFNULL(p_status, 1), p_user_id);
    SET v_id = LAST_INSERT_ID();
  ELSE
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = v_id AND is_deleted = 0) THEN
      SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Login not found';
    END IF;
    IF v_id = p_user_id AND (p_role <> 'ADMIN' OR IFNULL(p_status, 1) = 0) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'role::You cannot remove your own admin access or block yourself';
    END IF;
    IF IFNULL(p_status, 1) = 1 AND EXISTS (SELECT 1 FROM users u JOIN employees e ON e.id = u.employee_id
                                            WHERE u.id = v_id AND e.emp_status = 'RESIGNED') THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'status::The employee has resigned, so the login must stay blocked';
    END IF;

    UPDATE users
       SET username = v_username, role = p_role, status = IFNULL(p_status, 1),
           failed_attempts = IF(IFNULL(p_status, 1) = 1, 0, failed_attempts),
           locked_until = IF(IFNULL(p_status, 1) = 1, NULL, locked_until),
           updated_by = p_user_id, updated_at = NOW()
     WHERE id = v_id;
  END IF;

  SELECT v_id AS id, 'Login saved successfully' AS message;
END
