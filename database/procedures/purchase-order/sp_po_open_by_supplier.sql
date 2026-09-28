-- sp_po_open_by_supplier
-- Purpose : Orders of a supplier that can still be received against (SENT / PARTIAL).
-- Params  : p_supplier_id
-- Results : (1) id, po_no, po_date, expected_date, status, grand_total, pending_lines
-- Errors  : none
CREATE PROCEDURE sp_po_open_by_supplier(IN p_supplier_id INT)
BEGIN
  SELECT po.id, po.po_no, po.po_date, po.expected_date, po.po_status AS status, po.grand_total,
         (SELECT COUNT(*) FROM purchase_order_items pi WHERE pi.po_id = po.id AND pi.received_qty < pi.qty) AS pending_lines
    FROM purchase_orders po
   WHERE po.is_deleted = 0 AND po.supplier_id = p_supplier_id AND po.po_status IN ('SENT', 'PARTIAL')
   ORDER BY po.po_date DESC, po.id DESC;
END
