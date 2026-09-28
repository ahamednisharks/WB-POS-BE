-- sp_item_stock_adjust
-- Purpose : Manual stock movement for an item: opening stock, daily production of baked items, wastage / count
--           corrections. Positive p_qty adds stock, negative removes it.
-- Params  : p_item_id, p_type (OPENING|ADJUST), p_qty (signed), p_remarks, p_user_id
-- Results : (1) id, message, current_stock
-- Errors  : 45000 validation / insufficient stock, 45404 item not found
CREATE PROCEDURE sp_item_stock_adjust(
  IN p_item_id INT,
  IN p_type    VARCHAR(10),
  IN p_qty     DECIMAL(12,3),
  IN p_remarks VARCHAR(200),
  IN p_user_id INT
)
BEGIN
  DECLARE v_stock DECIMAL(12,3);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF IFNULL(p_type, '') NOT IN ('OPENING', 'ADJUST') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'type::Type must be OPENING or ADJUST';
  END IF;
  IF IFNULL(p_qty, 0) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'qty::Quantity cannot be 0';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM items WHERE id = p_item_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Item not found';
  END IF;

  START TRANSACTION;
  CALL sp_util_stock_post(p_item_id, p_type, 'items', p_item_id, GREATEST(p_qty, 0), GREATEST(-p_qty, 0), p_user_id);
  CALL sp_util_audit(p_user_id, CONCAT('STOCK_', p_type), 'items', p_item_id, NULL,
                     JSON_OBJECT('qty', p_qty, 'remarks', NULLIF(TRIM(p_remarks), '')));
  COMMIT;

  SELECT current_stock INTO v_stock FROM items WHERE id = p_item_id;
  SELECT p_item_id AS id, 'Stock updated' AS message, v_stock AS current_stock;
END
