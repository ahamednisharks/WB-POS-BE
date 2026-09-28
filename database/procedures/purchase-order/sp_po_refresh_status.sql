-- sp_po_refresh_status
-- Purpose : Internal (no result set): recomputes SENT / PARTIAL / RECEIVED from the received quantities.
--           DRAFT and CANCELLED orders are left alone.
-- Params  : p_po_id, p_user_id
-- Results : none
-- Errors  : none
CREATE PROCEDURE sp_po_refresh_status(IN p_po_id INT, IN p_user_id INT)
BEGIN
  DECLARE v_open     INT DEFAULT 0;
  DECLARE v_received INT DEFAULT 0;

  IF p_po_id IS NOT NULL THEN
    SELECT IFNULL(SUM(received_qty < qty), 0), IFNULL(SUM(received_qty > 0), 0)
      INTO v_open, v_received
      FROM purchase_order_items WHERE po_id = p_po_id;

    UPDATE purchase_orders
       SET po_status = CASE WHEN v_open = 0 THEN 'RECEIVED' WHEN v_received > 0 THEN 'PARTIAL' ELSE 'SENT' END,
           updated_by = p_user_id, updated_at = NOW()
     WHERE id = p_po_id AND po_status IN ('SENT', 'PARTIAL', 'RECEIVED');
  END IF;
END
