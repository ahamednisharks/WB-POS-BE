-- sp_combo_dropdown
-- Purpose : Combos that are active and valid today.
-- Params  : none
-- Results : (1) id, name, combo_price, actual_price, gst_percent
-- Errors  : none
CREATE PROCEDURE sp_combo_dropdown()
BEGIN
  SELECT id, combo_name AS name, combo_price, actual_price, gst_pct AS gst_percent
    FROM combos
   WHERE is_deleted = 0 AND status = 1
     AND (valid_from IS NULL OR valid_from <= CURDATE())
     AND (valid_to IS NULL OR valid_to >= CURDATE())
   ORDER BY combo_name;
END
