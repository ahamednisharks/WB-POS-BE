-- sp_unit_dropdown
-- Purpose : Active units for select boxes.
-- Params  : none
-- Results : (1) id, name, short_code, allow_decimal
-- Errors  : none
CREATE PROCEDURE sp_unit_dropdown()
BEGIN
  SELECT id, unit_name AS name, short_code, allow_decimal
    FROM units
   WHERE is_deleted = 0 AND status = 1
   ORDER BY unit_name;
END
