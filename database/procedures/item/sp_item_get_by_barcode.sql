-- sp_item_get_by_barcode
-- Purpose : Scanner lookup - active sale item by barcode (falls back to item code).
-- Params  : p_code
-- Results : (1) item row (same shape as sp_item_get)
-- Errors  : 45404 no item for the code
CREATE PROCEDURE sp_item_get_by_barcode(IN p_code VARCHAR(40))
BEGIN
  DECLARE v_id INT DEFAULT NULL;

  SELECT MIN(id) INTO v_id
    FROM items
   WHERE is_deleted = 0 AND status = 1 AND item_type IN ('SALE', 'BOTH')
     AND (barcode = TRIM(p_code) OR item_code = TRIM(p_code));

  IF v_id IS NULL THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'No item found for this barcode';
  END IF;

  CALL sp_item_get(v_id);
END
