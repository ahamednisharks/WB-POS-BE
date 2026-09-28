-- sp_employee_save
-- Purpose : Insert (p_id = 0, EMP001 code generated) or update an employee.
--           Aadhaar / bank account arrive already AES-encrypted from Node; p_aadhaar_hash (HMAC) detects duplicates.
--           Setting status RESIGNED blocks the employee's login automatically.
-- Params  : p_id, p_photo_url, p_full_name, p_employee_type_id, p_mobile, p_alt_mobile, p_email, p_gender, p_dob,
--           p_joining_date, p_address, p_aadhaar_enc, p_aadhaar_last4, p_aadhaar_hash, p_id_proof_url, p_id_proof_name,
--           p_emergency_name, p_emergency_mobile, p_bank_account_enc, p_ifsc, p_emp_status, p_resign_date, p_user_id
-- Results : (1) id, message
-- Errors  : 45000 validation, 45404 not found, 45409 duplicate mobile / Aadhaar
CREATE PROCEDURE sp_employee_save(
  IN p_id               INT,
  IN p_photo_url        VARCHAR(255),
  IN p_full_name        VARCHAR(80),
  IN p_employee_type_id INT,
  IN p_mobile           VARCHAR(10),
  IN p_alt_mobile       VARCHAR(10),
  IN p_email            VARCHAR(100),
  IN p_gender           VARCHAR(6),
  IN p_dob              DATE,
  IN p_joining_date     DATE,
  IN p_address          VARCHAR(255),
  IN p_aadhaar_enc      VARCHAR(255),
  IN p_aadhaar_last4    CHAR(4),
  IN p_aadhaar_hash     CHAR(64),
  IN p_id_proof_url     VARCHAR(255),
  IN p_id_proof_name    VARCHAR(150),
  IN p_emergency_name   VARCHAR(80),
  IN p_emergency_mobile VARCHAR(10),
  IN p_bank_account_enc VARCHAR(255),
  IN p_ifsc             VARCHAR(11),
  IN p_emp_status       VARCHAR(10),
  IN p_resign_date      DATE,
  IN p_user_id          INT
)
BEGIN
  DECLARE v_id     INT DEFAULT IFNULL(p_id, 0);
  DECLARE v_name   VARCHAR(80) DEFAULT TRIM(IFNULL(p_full_name, ''));
  DECLARE v_status VARCHAR(10) DEFAULT IFNULL(NULLIF(p_emp_status, ''), 'ACTIVE');
  DECLARE v_code   VARCHAR(20);
  DECLARE v_found  INT DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF v_name = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'fullName::Full name is required';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM employee_types WHERE id = p_employee_type_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'employeeTypeId::Employee type not found';
  END IF;
  IF IFNULL(p_mobile, '') NOT REGEXP '^[6-9][0-9]{9}$' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'mobile::Enter a valid 10-digit mobile number';
  END IF;
  IF EXISTS (SELECT 1 FROM employees WHERE mobile = p_mobile AND id <> v_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45409' SET MESSAGE_TEXT = 'mobile::Another employee has this mobile number';
  END IF;
  IF IFNULL(p_gender, '') NOT IN ('MALE', 'FEMALE', 'OTHER') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'gender::Select a gender';
  END IF;
  IF p_dob IS NOT NULL AND TIMESTAMPDIFF(YEAR, p_dob, CURDATE()) < 18 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'dob::Employee must be at least 18 years old';
  END IF;
  IF p_joining_date IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'joiningDate::Joining date is required';
  END IF;
  IF p_joining_date > CURDATE() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'joiningDate::Joining date cannot be in the future';
  END IF;
  IF TRIM(IFNULL(p_address, '')) = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'address::Address is required';
  END IF;
  IF p_aadhaar_hash IS NOT NULL AND EXISTS (SELECT 1 FROM employees WHERE aadhaar_hash = p_aadhaar_hash AND id <> v_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45409' SET MESSAGE_TEXT = 'aadhaar::Another employee has this Aadhaar number';
  END IF;
  IF v_status NOT IN ('ACTIVE', 'RESIGNED') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'status::Status must be ACTIVE or RESIGNED';
  END IF;
  IF v_status = 'RESIGNED' AND p_resign_date IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'resignDate::Resign date is required';
  END IF;
  IF v_status = 'RESIGNED' AND p_resign_date < p_joining_date THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'resignDate::Resign date cannot be before the joining date';
  END IF;

  START TRANSACTION;

  IF v_id = 0 THEN
    CALL sp_util_next_number('EMP', v_code);
    WHILE EXISTS (SELECT 1 FROM employees WHERE emp_code = v_code AND is_deleted = 0) DO
      CALL sp_util_next_number('EMP', v_code);
    END WHILE;

    INSERT INTO employees (emp_code, photo_url, full_name, employee_type_id, mobile, alt_mobile, email, gender, dob,
                           joining_date, address, aadhaar_enc, aadhaar_last4, aadhaar_hash, id_proof_url, id_proof_name,
                           emergency_name, emergency_mobile, bank_account_enc, ifsc, emp_status, resign_date, created_by)
    VALUES (v_code, p_photo_url, v_name, p_employee_type_id, p_mobile, NULLIF(p_alt_mobile, ''), NULLIF(TRIM(p_email), ''),
            p_gender, p_dob, p_joining_date, TRIM(p_address), p_aadhaar_enc, p_aadhaar_last4, p_aadhaar_hash,
            p_id_proof_url, p_id_proof_name, NULLIF(TRIM(p_emergency_name), ''), NULLIF(p_emergency_mobile, ''),
            p_bank_account_enc, NULLIF(UPPER(TRIM(p_ifsc)), ''), v_status,
            IF(v_status = 'RESIGNED', p_resign_date, NULL), p_user_id);
    SET v_id = LAST_INSERT_ID();
  ELSE
    SELECT COUNT(*) INTO v_found FROM employees WHERE id = v_id AND is_deleted = 0 FOR UPDATE;
    IF v_found = 0 THEN
      SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Employee not found';
    END IF;

    UPDATE employees
       SET photo_url = p_photo_url, full_name = v_name, employee_type_id = p_employee_type_id, mobile = p_mobile,
           alt_mobile = NULLIF(p_alt_mobile, ''), email = NULLIF(TRIM(p_email), ''), gender = p_gender, dob = p_dob,
           joining_date = p_joining_date, address = TRIM(p_address), aadhaar_enc = p_aadhaar_enc,
           aadhaar_last4 = p_aadhaar_last4, aadhaar_hash = p_aadhaar_hash, id_proof_url = p_id_proof_url,
           id_proof_name = p_id_proof_name, emergency_name = NULLIF(TRIM(p_emergency_name), ''),
           emergency_mobile = NULLIF(p_emergency_mobile, ''), bank_account_enc = p_bank_account_enc,
           ifsc = NULLIF(UPPER(TRIM(p_ifsc)), ''), emp_status = v_status,
           resign_date = IF(v_status = 'RESIGNED', p_resign_date, NULL),
           updated_by = p_user_id, updated_at = NOW()
     WHERE id = v_id;
  END IF;

  IF v_status = 'RESIGNED' THEN
    UPDATE users SET status = 0, updated_by = p_user_id, updated_at = NOW()
     WHERE employee_id = v_id AND is_deleted = 0 AND status = 1;
  END IF;

  COMMIT;

  SELECT v_id AS id, 'Employee saved successfully' AS message;
END
