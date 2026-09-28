-- sp_item_stock_ledger
-- Purpose : Stock movements of one item (newest first) with the document number that caused each one.
-- Params  : p_item_id, p_from DATE, p_to DATE, p_page, p_limit
-- Results : (1) item header, (2) ledger rows, (3) total
-- Errors  : 45404 item not found
CREATE PROCEDURE sp_item_stock_ledger(
  IN p_item_id INT,
  IN p_from    DATE,
  IN p_to      DATE,
  IN p_page    INT,
  IN p_limit   INT
)
BEGIN
  DECLARE v_limit  INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 50), 1), 1000);
  DECLARE v_offset INT DEFAULT (GREATEST(IFNULL(p_page, 1), 1) - 1) * v_limit;

  IF NOT EXISTS (SELECT 1 FROM items WHERE id = p_item_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Item not found';
  END IF;

  SELECT i.id, i.item_code AS code, i.item_name AS name, i.item_type AS type, u.short_code AS unit_code,
         i.current_stock, i.min_stock
    FROM items i JOIN units u ON u.id = i.unit_id
   WHERE i.id = p_item_id;

  SELECT l.id, l.txn_date, l.txn_type AS type, l.ref_table, l.ref_id,
         CASE l.ref_table
           WHEN 'bills'            THEN (SELECT b.bill_no FROM bills b WHERE b.id = l.ref_id)
           WHEN 'purchase_entries' THEN (SELECT pe.pe_no FROM purchase_entries pe WHERE pe.id = l.ref_id)
         END AS ref_no,
         l.qty_in, l.qty_out, l.balance_after
    FROM stock_ledger l
   WHERE l.item_id = p_item_id
     AND (p_from IS NULL OR l.txn_date >= p_from)
     AND (p_to IS NULL OR l.txn_date < p_to + INTERVAL 1 DAY)
   ORDER BY l.id DESC
   LIMIT v_limit OFFSET v_offset;

  SELECT COUNT(*) AS total
    FROM stock_ledger l
   WHERE l.item_id = p_item_id
     AND (p_from IS NULL OR l.txn_date >= p_from)
     AND (p_to IS NULL OR l.txn_date < p_to + INTERVAL 1 DAY);
END
