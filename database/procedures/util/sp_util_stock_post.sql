-- sp_util_stock_post
-- Purpose : Moves stock for one item: locks the item row, updates items.current_stock and writes
--           a stock_ledger row with the running balance.
--           Negative stock is refused for RAW items, and for SALE/BOTH items when
--           shop_settings.allow_negative_stock = 0.
-- Params  : p_item_id, p_type (OPENING|PURCHASE|SALE|SALE_CANCEL|PE_EDIT|ADJUST), p_ref_table, p_ref_id,
--           p_qty_in, p_qty_out, p_user_id
-- Results : none
-- Errors  : 45404 item not found, 45000 insufficient stock
CREATE PROCEDURE sp_util_stock_post(
  IN p_item_id   INT,
  IN p_type      VARCHAR(12),
  IN p_ref_table VARCHAR(40),
  IN p_ref_id    INT,
  IN p_qty_in    DECIMAL(12,3),
  IN p_qty_out   DECIMAL(12,3),
  IN p_user_id   INT
)
BEGIN
  DECLARE v_stock     DECIMAL(12,3) DEFAULT NULL;
  DECLARE v_type      VARCHAR(4);
  DECLARE v_name      VARCHAR(60);
  DECLARE v_allow_neg INT DEFAULT 1;
  DECLARE v_in        DECIMAL(12,3) DEFAULT IFNULL(p_qty_in, 0);
  DECLARE v_out       DECIMAL(12,3) DEFAULT IFNULL(p_qty_out, 0);
  DECLARE v_new       DECIMAL(12,3);
  DECLARE v_msg       VARCHAR(128);

  SELECT current_stock, item_type, item_name INTO v_stock, v_type, v_name
    FROM items WHERE id = p_item_id FOR UPDATE;

  IF v_stock IS NULL THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Item not found';
  END IF;

  SELECT IFNULL(MAX(allow_negative_stock), 1) INTO v_allow_neg FROM shop_settings WHERE id = 1;
  SET v_new = v_stock + v_in - v_out;

  IF v_new < 0 AND v_out > 0 AND (v_type = 'RAW' OR v_allow_neg = 0) THEN
    SET v_msg = LEFT(CONCAT('Insufficient stock for ', v_name, ' (available ', TRIM(TRAILING '.' FROM TRIM(TRAILING '0' FROM v_stock)), ')'), 128);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  UPDATE items SET current_stock = v_new WHERE id = p_item_id;

  INSERT INTO stock_ledger (item_id, txn_date, txn_type, ref_table, ref_id, qty_in, qty_out, balance_after, created_by)
  VALUES (p_item_id, NOW(), p_type, p_ref_table, p_ref_id, v_in, v_out, v_new, p_user_id);
END
