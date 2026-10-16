-- sp_stock_issue_cancel
-- Purpose : Cancels a posted stock issue (ADMIN only, any day): every line's quantity is put back into stock
--           (stock_ledger ISSUE_CANCEL) and the issue is marked CANCELLED with the reason.
-- Params  : p_id, p_reason, p_user_id, p_role (ADMIN|CASHIER)
-- Results : (1) id, message
-- Errors  : 45000 reason missing / already cancelled, 45403 not admin, 45404 not found
CREATE PROCEDURE sp_stock_issue_cancel(
  IN p_id      INT,
  IN p_reason  VARCHAR(200),
  IN p_user_id INT,
  IN p_role    VARCHAR(10)
)
BEGIN
  DECLARE v_status VARCHAR(10) DEFAULT NULL;
  DECLARE v_no     VARCHAR(20) DEFAULT NULL;
  DECLARE v_value  DECIMAL(12,2) DEFAULT 0;
  DECLARE v_reason VARCHAR(200) DEFAULT TRIM(IFNULL(p_reason, ''));
  DECLARE v_i      INT DEFAULT 0;
  DECLARE v_n      INT DEFAULT 0;
  DECLARE v_item   INT;
  DECLARE v_qty    DECIMAL(12,3);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF IFNULL(p_role, '') <> 'ADMIN' THEN
    SIGNAL SQLSTATE '45403' SET MESSAGE_TEXT = 'Only Admin can cancel a stock issue';
  END IF;
  IF v_reason = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'reason::Cancel reason is required';
  END IF;

  START TRANSACTION;

  SELECT issue_status, issue_no, total_value INTO v_status, v_no, v_value
    FROM stock_issues WHERE id = p_id FOR UPDATE;
  IF v_status IS NULL THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Stock issue not found';
  END IF;
  IF v_status = 'CANCELLED' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock issue is already cancelled';
  END IF;

  DROP TEMPORARY TABLE IF EXISTS tmp_si_undo;
  CREATE TEMPORARY TABLE tmp_si_undo (
    seq INT NOT NULL AUTO_INCREMENT PRIMARY KEY, item_id INT NOT NULL, qty DECIMAL(12,3) NOT NULL
  );
  INSERT INTO tmp_si_undo (item_id, qty)
  SELECT item_id, qty FROM stock_issue_items WHERE si_id = p_id ORDER BY item_id;

  SELECT COUNT(*) INTO v_n FROM tmp_si_undo;
  SET v_i = 1;
  WHILE v_i <= v_n DO
    SELECT item_id, qty INTO v_item, v_qty FROM tmp_si_undo WHERE seq = v_i;
    CALL sp_util_stock_post(v_item, 'ISSUE_CANCEL', 'stock_issues', p_id, v_qty, 0, p_user_id);
    SET v_i = v_i + 1;
  END WHILE;

  UPDATE stock_issues
     SET issue_status = 'CANCELLED', cancel_reason = v_reason, cancelled_by = p_user_id, cancelled_at = NOW(),
         updated_by = p_user_id, updated_at = NOW()
   WHERE id = p_id;

  CALL sp_util_audit(p_user_id, 'CANCEL', 'stock_issues', p_id,
                     JSON_OBJECT('status', 'POSTED', 'totalValue', v_value),
                     JSON_OBJECT('status', 'CANCELLED', 'reason', v_reason));

  COMMIT;
  DROP TEMPORARY TABLE IF EXISTS tmp_si_undo;

  SELECT p_id AS id, CONCAT('Stock issue ', v_no, ' cancelled - stock restored') AS message;
END
