-- sp_supplier_delete
-- Purpose : Soft-deletes a supplier; if it has purchase orders / entries, marks it inactive instead.
-- Params  : p_id, p_user_id
-- Results : (1) id, message, deleted
-- Errors  : 45404 not found
CREATE PROCEDURE sp_supplier_delete(IN p_id INT, IN p_user_id INT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM suppliers WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Supplier not found';
  END IF;

  IF EXISTS (SELECT 1 FROM purchase_orders WHERE supplier_id = p_id AND is_deleted = 0)
     OR EXISTS (SELECT 1 FROM purchase_entries WHERE supplier_id = p_id AND is_deleted = 0) THEN
    UPDATE suppliers SET status = 0, updated_by = p_user_id, updated_at = NOW() WHERE id = p_id;
    CALL sp_util_audit(p_user_id, 'DEACTIVATE', 'suppliers', p_id, NULL, JSON_OBJECT('status', 0));
    SELECT p_id AS id, 'Supplier has purchase records - marked inactive' AS message, 0 AS deleted;
  ELSE
    UPDATE suppliers SET is_deleted = 1, updated_by = p_user_id, updated_at = NOW() WHERE id = p_id;
    CALL sp_util_audit(p_user_id, 'DELETE', 'suppliers', p_id, NULL, NULL);
    SELECT p_id AS id, 'Supplier deleted successfully' AS message, 1 AS deleted;
  END IF;
END
