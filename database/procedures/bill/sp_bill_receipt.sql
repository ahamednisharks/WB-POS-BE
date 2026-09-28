-- sp_bill_receipt
-- Purpose : Everything needed to print a receipt; reprints are flagged DUPLICATE.
-- Params  : p_id, p_duplicate (1 = reprint), p_user_id, p_role
-- Results : (1) shop settings, (2) header, (3) lines, (4) payments, (5) history, (6) copy flag (is_duplicate, copy_label)
-- Errors  : 45404 not found / not visible
CREATE PROCEDURE sp_bill_receipt(IN p_id INT, IN p_duplicate TINYINT, IN p_user_id INT, IN p_role VARCHAR(10))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM bills
                  WHERE id = p_id AND is_deleted = 0
                    AND (IFNULL(p_role, '') <> 'CASHIER' OR cashier_id = p_user_id)) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Bill not found';
  END IF;

  CALL sp_settings_get();
  CALL sp_bill_get(p_id, p_user_id, p_role);

  SELECT IFNULL(p_duplicate, 0) AS is_duplicate, IF(IFNULL(p_duplicate, 0) = 1, 'DUPLICATE', 'ORIGINAL') AS copy_label;
END
