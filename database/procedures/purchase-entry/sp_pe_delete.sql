-- sp_pe_delete
-- Purpose : Deletes a purchase entry on the day it was created: stock taken back (PE_EDIT), PO received qty and status
--           restored, supplier balance corrected, its payments and cash-out transactions removed.
-- Params  : p_id, p_user_id
-- Results : (1) id, message, deleted
-- Errors  : 45000 not the same day / stock already used, 45404 not found
CREATE PROCEDURE sp_pe_delete(IN p_id INT, IN p_user_id INT)
BEGIN
  DECLARE v_supplier INT DEFAULT NULL;
  DECLARE v_po       INT;
  DECLARE v_grand    DECIMAL(12,2);
  DECLARE v_paid     DECIMAL(12,2);
  DECLARE v_created  DATE;
  DECLARE v_pe_no    VARCHAR(20);
  DECLARE v_i        INT DEFAULT 0;
  DECLARE v_n        INT DEFAULT 0;
  DECLARE v_item     INT;
  DECLARE v_qty      DECIMAL(12,3);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  START TRANSACTION;

  SELECT supplier_id, po_id, grand_total, paid_amount, DATE(created_at), pe_no
    INTO v_supplier, v_po, v_grand, v_paid, v_created, v_pe_no
    FROM purchase_entries WHERE id = p_id AND is_deleted = 0 FOR UPDATE;

  IF v_supplier IS NULL THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Purchase entry not found';
  END IF;
  IF v_created <> CURDATE() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Purchase entries can only be deleted on the day they were created';
  END IF;

  DROP TEMPORARY TABLE IF EXISTS tmp_pe_del;
  CREATE TEMPORARY TABLE tmp_pe_del (
    seq INT NOT NULL AUTO_INCREMENT PRIMARY KEY, item_id INT NOT NULL, qty DECIMAL(12,3) NOT NULL
  );
  INSERT INTO tmp_pe_del (item_id, qty)
  SELECT item_id, SUM(received_qty) FROM purchase_entry_items WHERE pe_id = p_id GROUP BY item_id ORDER BY item_id;

  SELECT COUNT(*) INTO v_n FROM tmp_pe_del;
  SET v_i = 1;
  WHILE v_i <= v_n DO
    SELECT item_id, qty INTO v_item, v_qty FROM tmp_pe_del WHERE seq = v_i;
    CALL sp_util_stock_post(v_item, 'PE_EDIT', 'purchase_entries', p_id, 0, v_qty, p_user_id);
    SET v_i = v_i + 1;
  END WHILE;
  DROP TEMPORARY TABLE IF EXISTS tmp_pe_del;

  UPDATE purchase_order_items pi
    JOIN (SELECT po_item_id, SUM(received_qty) AS q FROM purchase_entry_items
           WHERE pe_id = p_id AND po_item_id IS NOT NULL GROUP BY po_item_id) x ON x.po_item_id = pi.id
     SET pi.received_qty = GREATEST(pi.received_qty - x.q, 0);
  CALL sp_po_refresh_status(v_po, p_user_id);

  UPDATE suppliers SET current_balance = current_balance - v_grand + v_paid WHERE id = v_supplier;
  DELETE FROM transactions WHERE purchase_entry_id = p_id;
  DELETE FROM supplier_payments WHERE pe_id = p_id;

  UPDATE purchase_entries SET is_deleted = 1, updated_by = p_user_id, updated_at = NOW() WHERE id = p_id;
  CALL sp_util_audit(p_user_id, 'DELETE', 'purchase_entries', p_id,
                     JSON_OBJECT('peNo', v_pe_no, 'grandTotal', v_grand, 'paid', v_paid), NULL);

  COMMIT;

  SELECT p_id AS id, CONCAT('Purchase entry ', v_pe_no, ' deleted') AS message, 1 AS deleted;
END
