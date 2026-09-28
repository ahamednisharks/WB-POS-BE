-- sp_unit_delete
-- Purpose : Soft-deletes a unit; if items use it, marks it inactive instead.
-- Params  : p_id, p_user_id
-- Results : (1) id, message, deleted (1 = deleted, 0 = marked inactive)
-- Errors  : 45404 not found
CREATE PROCEDURE sp_unit_delete(IN p_id INT, IN p_user_id INT)
BEGIN
  DECLARE v_used INT DEFAULT 0;

  IF NOT EXISTS (SELECT 1 FROM units WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Unit not found';
  END IF;

  SELECT COUNT(*) INTO v_used FROM items WHERE unit_id = p_id AND is_deleted = 0;

  IF v_used > 0 THEN
    UPDATE units SET status = 0, updated_by = p_user_id, updated_at = NOW() WHERE id = p_id;
    CALL sp_util_audit(p_user_id, 'DEACTIVATE', 'units', p_id, NULL, JSON_OBJECT('status', 0));
    SELECT p_id AS id, CONCAT('In use by ', v_used, ' item(s) - marked inactive') AS message, 0 AS deleted;
  ELSE
    UPDATE units SET is_deleted = 1, updated_by = p_user_id, updated_at = NOW() WHERE id = p_id;
    CALL sp_util_audit(p_user_id, 'DELETE', 'units', p_id, NULL, NULL);
    SELECT p_id AS id, 'Unit deleted successfully' AS message, 1 AS deleted;
  END IF;
END
