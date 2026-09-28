-- sp_employee_type_dropdown
-- Purpose : Active employee types for select boxes.
-- Params  : none
-- Results : (1) id, name, can_login
-- Errors  : none
CREATE PROCEDURE sp_employee_type_dropdown()
BEGIN
  SELECT id, type_name AS name, can_login
    FROM employee_types
   WHERE is_deleted = 0 AND status = 1
   ORDER BY type_name;
END
