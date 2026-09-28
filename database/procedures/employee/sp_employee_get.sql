-- sp_employee_get
-- Purpose : One employee (ADMIN only). Encrypted Aadhaar / bank values are decrypted in Node.
-- Params  : p_id
-- Results : (1) employee row
-- Errors  : 45404 not found
CREATE PROCEDURE sp_employee_get(IN p_id INT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM employees WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Employee not found';
  END IF;

  SELECT e.id, e.emp_code, e.photo_url AS photo, e.full_name, e.employee_type_id, t.type_name AS employee_type_name,
         t.can_login, e.mobile, IFNULL(e.alt_mobile, '') AS alt_mobile, IFNULL(e.email, '') AS email, e.gender,
         e.dob, e.joining_date, IFNULL(e.address, '') AS address, e.aadhaar_last4, e.aadhaar_enc,
         e.id_proof_url, e.id_proof_name, IFNULL(e.emergency_name, '') AS emergency_name,
         IFNULL(e.emergency_mobile, '') AS emergency_mobile, e.bank_account_enc, IFNULL(e.ifsc, '') AS ifsc,
         e.emp_status AS status, e.resign_date,
         (SELECT u.id FROM users u WHERE u.employee_id = e.id AND u.is_deleted = 0 LIMIT 1) AS login_id,
         e.created_at, IFNULL(e.updated_at, e.created_at) AS updated_at
    FROM employees e
    JOIN employee_types t ON t.id = e.employee_type_id
   WHERE e.id = p_id;
END
