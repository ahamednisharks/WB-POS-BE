-- sp_auth_login_result
-- Purpose : Login step 2 - records the outcome of the password check.
--           Failure: failed_attempts + 1; the 5th failure locks the account for 15 minutes.
--           Success: refused if locked / blocked / employee resigned, otherwise resets the counter,
--           stamps last_login_at and returns the user profile.
--           Runs without a transaction on purpose so the attempt counter survives the SIGNAL.
-- Params  : p_user_id, p_success (1 = password matched)
-- Results : (1) user profile (same as sp_auth_me) on success
-- Errors  : 45401 wrong password, 45423 locked / blocked
CREATE PROCEDURE sp_auth_login_result(IN p_user_id INT, IN p_success TINYINT)
BEGIN
  DECLARE v_found        INT DEFAULT 0;
  DECLARE v_locked_until DATETIME DEFAULT NULL;
  DECLARE v_status       INT DEFAULT 0;
  DECLARE v_emp_status   VARCHAR(10) DEFAULT NULL;
  DECLARE v_attempts     INT DEFAULT 0;
  DECLARE v_minutes      INT;
  DECLARE v_msg          VARCHAR(128);

  SELECT COUNT(*), MAX(u.locked_until), MAX(u.status), MAX(e.emp_status), MAX(u.failed_attempts)
    INTO v_found, v_locked_until, v_status, v_emp_status, v_attempts
    FROM users u
    LEFT JOIN employees e ON e.id = u.employee_id
   WHERE u.id = p_user_id AND u.is_deleted = 0;

  IF v_found = 0 THEN
    SIGNAL SQLSTATE '45401' SET MESSAGE_TEXT = 'Invalid username or password';
  END IF;

  IF v_locked_until IS NOT NULL AND v_locked_until > NOW() THEN
    SET v_minutes = GREATEST(1, CEIL(TIMESTAMPDIFF(SECOND, NOW(), v_locked_until) / 60));
    SET v_msg = CONCAT('Account locked after too many failed attempts. Try again in ', v_minutes, ' minute(s).');
    SIGNAL SQLSTATE '45423' SET MESSAGE_TEXT = v_msg;
  END IF;

  IF IFNULL(p_success, 0) = 0 THEN
    IF v_attempts + 1 >= 5 THEN
      UPDATE users SET failed_attempts = 0, locked_until = NOW() + INTERVAL 15 MINUTE WHERE id = p_user_id;
      SIGNAL SQLSTATE '45423' SET MESSAGE_TEXT = 'Too many failed attempts. Your account is locked for 15 minutes.';
    END IF;
    UPDATE users SET failed_attempts = failed_attempts + 1 WHERE id = p_user_id;
    SIGNAL SQLSTATE '45401' SET MESSAGE_TEXT = 'Invalid username or password';
  END IF;

  IF v_status = 0 OR v_emp_status = 'RESIGNED' THEN
    SIGNAL SQLSTATE '45423' SET MESSAGE_TEXT = 'Your account is blocked. Contact Admin.';
  END IF;

  UPDATE users SET failed_attempts = 0, locked_until = NULL, last_login_at = NOW() WHERE id = p_user_id;

  CALL sp_auth_me(p_user_id);
END
