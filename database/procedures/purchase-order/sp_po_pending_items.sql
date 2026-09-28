-- sp_po_pending_items
-- Purpose : Lines of a PO still to be received ("Convert to PE").
-- Params  : p_po_id
-- Results : (1) po_item_id, item_id, item_name, unit_code, ordered_qty, received_qty, pending_qty, rate, gst_percent
-- Errors  : 45404 not found
CREATE PROCEDURE sp_po_pending_items(IN p_po_id INT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM purchase_orders WHERE id = p_po_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Purchase order not found';
  END IF;

  SELECT pi.id AS po_item_id, pi.item_id, i.item_name, u.short_code AS unit_code, pi.qty AS ordered_qty,
         pi.received_qty, pi.qty - pi.received_qty AS pending_qty, pi.rate, pi.gst_pct AS gst_percent
    FROM purchase_order_items pi
    JOIN items i ON i.id = pi.item_id
    JOIN units u ON u.id = i.unit_id
   WHERE pi.po_id = p_po_id AND pi.received_qty < pi.qty
   ORDER BY pi.id;
END
