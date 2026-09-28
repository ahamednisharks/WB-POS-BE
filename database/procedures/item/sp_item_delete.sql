-- sp_item_delete
-- Purpose : Soft-deletes an item; if it is used in combos, bills or purchases, marks it inactive instead.
-- Params  : p_id, p_user_id
-- Results : (1) id, message, deleted
-- Errors  : 45404 not found
CREATE PROCEDURE sp_item_delete(IN p_id INT, IN p_user_id INT)
BEGIN
  DECLARE v_used INT DEFAULT 0;

  IF NOT EXISTS (SELECT 1 FROM items WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Item not found';
  END IF;

  SET v_used = EXISTS (SELECT 1 FROM combo_items ci JOIN combos c ON c.id = ci.combo_id WHERE ci.item_id = p_id AND c.is_deleted = 0)
            OR EXISTS (SELECT 1 FROM bill_items WHERE item_id = p_id)
            OR EXISTS (SELECT 1 FROM purchase_order_items WHERE item_id = p_id)
            OR EXISTS (SELECT 1 FROM purchase_entry_items WHERE item_id = p_id)
            OR EXISTS (SELECT 1 FROM stock_ledger WHERE item_id = p_id);

  IF v_used THEN
    UPDATE items SET status = 0, updated_by = p_user_id, updated_at = NOW() WHERE id = p_id;
    CALL sp_util_audit(p_user_id, 'DEACTIVATE', 'items', p_id, NULL, JSON_OBJECT('status', 0));
    SELECT p_id AS id, 'In use in combos, bills or purchases - marked inactive' AS message, 0 AS deleted;
  ELSE
    UPDATE items SET is_deleted = 1, updated_by = p_user_id, updated_at = NOW() WHERE id = p_id;
    CALL sp_util_audit(p_user_id, 'DELETE', 'items', p_id, NULL, NULL);
    SELECT p_id AS id, 'Item deleted successfully' AS message, 1 AS deleted;
  END IF;
END
