-- sp_login_eligible_employees
-- Purpose : Active employees whose type allows login and who do not have a login yet.
-- Params  : none
-- Results : (1) id, emp_code, full_name, employee_type_name, mobile
-- Errors  : none
CREATE PROCEDURE sp_login_eligible_employees()
BEGIN
  SELECT e.id, e.emp_code, e.full_name, t.type_name AS employee_type_name, e.mobile
    FROM employees e
    JOIN employee_types t ON t.id = e.employee_type_id
   WHERE e.is_deleted = 0 AND e.emp_status = 'ACTIVE' AND t.can_login = 1 AND t.is_deleted = 0
     AND NOT EXISTS (SELECT 1 FROM users u WHERE u.employee_id = e.id AND u.is_deleted = 0)
   ORDER BY e.full_name;
END
