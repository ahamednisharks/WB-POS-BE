-- sp_employee_list
-- Purpose : Paged employee list. Encrypted columns are returned as-is; Node masks them.
-- Params  : p_search (name, code, mobile, type), p_employee_type_id, p_emp_status (ACTIVE|RESIGNED|NULL),
--           p_sort_by (empCode|fullName|employeeTypeName|mobile|joiningDate|status|createdAt), p_sort_dir, p_page, p_limit
-- Results : (1) rows, (2) total
-- Errors  : none
CREATE PROCEDURE sp_employee_list(
  IN p_search           VARCHAR(100),
  IN p_employee_type_id INT,
  IN p_emp_status       VARCHAR(10),
  IN p_sort_by          VARCHAR(30),
  IN p_sort_dir         VARCHAR(4),
  IN p_page             INT,
  IN p_limit            INT
)
BEGIN
  DECLARE v_limit  INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 10), 1), 1000);
  DECLARE v_offset INT DEFAULT (GREATEST(IFNULL(p_page, 1), 1) - 1) * v_limit;

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
   WHERE e.is_deleted = 0
     AND (p_employee_type_id IS NULL OR e.employee_type_id = p_employee_type_id)
     AND (IFNULL(p_emp_status, '') = '' OR e.emp_status = p_emp_status)
     AND (IFNULL(p_search, '') = ''
          OR e.full_name LIKE CONCAT('%', p_search, '%')
          OR e.emp_code LIKE CONCAT('%', p_search, '%')
          OR e.mobile LIKE CONCAT('%', p_search, '%')
          OR t.type_name LIKE CONCAT('%', p_search, '%'))
   ORDER BY
     CASE WHEN p_sort_by = 'empCode'          AND p_sort_dir = 'asc'  THEN e.emp_code END ASC,
     CASE WHEN p_sort_by = 'empCode'          AND p_sort_dir = 'desc' THEN e.emp_code END DESC,
     CASE WHEN p_sort_by = 'fullName'         AND p_sort_dir = 'asc'  THEN e.full_name END ASC,
     CASE WHEN p_sort_by = 'fullName'         AND p_sort_dir = 'desc' THEN e.full_name END DESC,
     CASE WHEN p_sort_by = 'employeeTypeName' AND p_sort_dir = 'asc'  THEN t.type_name END ASC,
     CASE WHEN p_sort_by = 'employeeTypeName' AND p_sort_dir = 'desc' THEN t.type_name END DESC,
     CASE WHEN p_sort_by = 'mobile'           AND p_sort_dir = 'asc'  THEN e.mobile END ASC,
     CASE WHEN p_sort_by = 'mobile'           AND p_sort_dir = 'desc' THEN e.mobile END DESC,
     CASE WHEN p_sort_by = 'joiningDate'      AND p_sort_dir = 'asc'  THEN e.joining_date END ASC,
     CASE WHEN p_sort_by = 'joiningDate'      AND p_sort_dir = 'desc' THEN e.joining_date END DESC,
     CASE WHEN p_sort_by = 'status'           AND p_sort_dir = 'asc'  THEN e.emp_status END ASC,
     CASE WHEN p_sort_by = 'status'           AND p_sort_dir = 'desc' THEN e.emp_status END DESC,
     CASE WHEN p_sort_by = 'createdAt'        AND p_sort_dir = 'asc'  THEN e.id END ASC,
     e.id DESC
   LIMIT v_limit OFFSET v_offset;

  SELECT COUNT(*) AS total
    FROM employees e
    JOIN employee_types t ON t.id = e.employee_type_id
   WHERE e.is_deleted = 0
     AND (p_employee_type_id IS NULL OR e.employee_type_id = p_employee_type_id)
     AND (IFNULL(p_emp_status, '') = '' OR e.emp_status = p_emp_status)
     AND (IFNULL(p_search, '') = ''
          OR e.full_name LIKE CONCAT('%', p_search, '%')
          OR e.emp_code LIKE CONCAT('%', p_search, '%')
          OR e.mobile LIKE CONCAT('%', p_search, '%')
          OR t.type_name LIKE CONCAT('%', p_search, '%'));
END
