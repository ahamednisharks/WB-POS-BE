-- sp_employee_dropdown
-- Purpose : Active employees for select boxes.
-- Params  : none
-- Results : (1) id, emp_code, full_name, employee_type_name, can_login, mobile
-- Errors  : none
CREATE PROCEDURE sp_employee_dropdown()
BEGIN
  SELECT e.id, e.emp_code, e.full_name, t.type_name AS employee_type_name, t.can_login, e.mobile
    FROM employees e
    JOIN employee_types t ON t.id = e.employee_type_id
   WHERE e.is_deleted = 0 AND e.emp_status = 'ACTIVE'
   ORDER BY e.full_name;
END
