-- sp_po_get
-- Purpose : One purchase order with its items and pending quantities.
-- Params  : p_id
-- Results : (1) header, (2) items (po_item_id, item_id, item_name, unit_code, qty, received_qty, pending_qty, rate,
--               gst_percent, amount, gst_amount)
-- Errors  : 45404 not found
CREATE PROCEDURE sp_po_get(IN p_id INT)
BEGIN
  DECLARE v_shop_state CHAR(2);

  IF NOT EXISTS (SELECT 1 FROM purchase_orders WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Purchase order not found';
  END IF;

  SELECT MAX(state_code) INTO v_shop_state FROM shop_settings WHERE id = 1;

  SELECT po.id, po.po_no, po.po_date, po.supplier_id, s.supplier_name, IFNULL(s.gstin, '') AS supplier_gstin,
         st.state_name AS supplier_state, s.mobile AS supplier_mobile, IFNULL(s.address, '') AS supplier_address,
         IF(s.state_code <> v_shop_state, 1, 0) AS is_inter_state,
         po.expected_date, IFNULL(po.notes, '') AS notes,
         po.sub_total, po.cgst, po.sgst, po.igst, po.cgst + po.sgst + po.igst AS total_gst, po.other_charges,
         po.round_off, po.grand_total, po.po_status AS status, po.cancel_reason,
         po.created_at, IFNULL(po.updated_at, po.created_at) AS updated_at
    FROM purchase_orders po
    JOIN suppliers s ON s.id = po.supplier_id
    JOIN states st   ON st.state_code = s.state_code
   WHERE po.id = p_id;

  SELECT pi.id AS po_item_id, pi.item_id, i.item_name, u.short_code AS unit_code, pi.qty, pi.received_qty,
         GREATEST(pi.qty - pi.received_qty, 0) AS pending_qty, pi.rate, pi.gst_pct AS gst_percent,
         pi.amount, pi.gst_amount
    FROM purchase_order_items pi
    JOIN items i ON i.id = pi.item_id
    JOIN units u ON u.id = i.unit_id
   WHERE pi.po_id = p_id
   ORDER BY pi.id;
END
