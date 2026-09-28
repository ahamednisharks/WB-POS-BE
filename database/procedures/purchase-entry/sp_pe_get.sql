-- sp_pe_get
-- Purpose : One purchase entry with items and payments.
-- Params  : p_id
-- Results : (1) header, (2) items, (3) payments
-- Errors  : 45404 not found
CREATE PROCEDURE sp_pe_get(IN p_id INT)
BEGIN
  DECLARE v_shop_state CHAR(2);

  IF NOT EXISTS (SELECT 1 FROM purchase_entries WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Purchase entry not found';
  END IF;

  SELECT MAX(state_code) INTO v_shop_state FROM shop_settings WHERE id = 1;

  SELECT pe.id, pe.pe_no, pe.pe_date, pe.supplier_id, s.supplier_name, st.state_name AS supplier_state,
         IFNULL(s.gstin, '') AS supplier_gstin, IF(s.state_code <> v_shop_state, 1, 0) AS is_inter_state,
         pe.po_id, po.po_no, pe.supplier_invoice_no AS invoice_no, pe.invoice_date,
         pe.invoice_file_url, pe.invoice_file_name,
         pe.sub_total, pe.cgst, pe.sgst, pe.igst, pe.cgst + pe.sgst + pe.igst AS total_gst, pe.discount,
         pe.other_charges, pe.round_off, pe.grand_total, pe.paid_amount, pe.balance, pe.due_date,
         CASE pe.payment_status WHEN 'PARTIAL' THEN 'PARTLY_PAID' ELSE pe.payment_status END AS payment_status,
         IF(DATE(pe.created_at) = CURDATE(), 1, 0) AS is_editable,
         pe.created_at, IFNULL(pe.updated_at, pe.created_at) AS updated_at
    FROM purchase_entries pe
    JOIN suppliers s ON s.id = pe.supplier_id
    JOIN states st   ON st.state_code = s.state_code
    LEFT JOIN purchase_orders po ON po.id = pe.po_id
   WHERE pe.id = p_id;

  SELECT pi.item_id, i.item_name, u.short_code AS unit_code, pi.po_item_id, pi.ordered_qty, pi.received_qty, pi.rate,
         pi.gst_pct AS gst_percent, pi.expiry_date, pi.amount, pi.cgst + pi.sgst + pi.igst AS gst_amount,
         pi.cgst, pi.sgst, pi.igst
    FROM purchase_entry_items pi
    JOIN items i ON i.id = pi.item_id
    JOIN units u ON u.id = i.unit_id
   WHERE pi.pe_id = p_id
   ORDER BY pi.id;

  SELECT sp.id, sp.amount, sp.payment_mode AS mode, sp.payment_date AS date, sp.reference_no AS reference, sp.created_at
    FROM supplier_payments sp
   WHERE sp.pe_id = p_id
   ORDER BY sp.payment_date, sp.id;
END
