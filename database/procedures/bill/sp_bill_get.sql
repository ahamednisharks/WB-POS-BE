-- sp_bill_get
-- Purpose : Full bill for the detail screen / printing. Cashiers can only open their own bills.
-- Params  : p_id, p_user_id, p_role
-- Results : (1) header, (2) lines, (3) payments, (4) status history
-- Errors  : 45404 not found (or not visible to this cashier)
CREATE PROCEDURE sp_bill_get(IN p_id INT, IN p_user_id INT, IN p_role VARCHAR(10))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM bills
                  WHERE id = p_id AND is_deleted = 0
                    AND (IFNULL(p_role, '') <> 'CASHIER' OR cashier_id = p_user_id)) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Bill not found';
  END IF;

  SELECT b.id, b.bill_no, b.bill_date, b.cashier_id,
         COALESCE(e.full_name, IF(u.employee_id IS NULL, 'Administrator', u.username)) AS cashier_name,
         IFNULL(b.customer_mobile, '') AS customer_mobile, IFNULL(b.customer_name, '') AS customer_name,
         b.item_count, b.discount_type, b.discount_value, b.sub_total, b.discount_amount, b.taxable_amount,
         b.cgst, b.sgst, b.cgst + b.sgst AS total_gst, b.round_off, b.grand_total, b.payment_mode,
         (SELECT SUM(bp.cash_received) FROM bill_payments bp WHERE bp.bill_id = b.id AND bp.payment_mode = 'CASH') AS cash_received,
         (SELECT SUM(bp.change_returned) FROM bill_payments bp WHERE bp.bill_id = b.id AND bp.payment_mode = 'CASH') AS change_returned,
         b.bill_status AS status, b.cancel_reason, b.cancelled_at, b.client_ref, b.device_id,
         b.created_at, IFNULL(b.updated_at, b.created_at) AS updated_at
    FROM bills b
    JOIN users u ON u.id = b.cashier_id
    LEFT JOIN employees e ON e.id = u.employee_id
   WHERE b.id = p_id;

  SELECT IF(bi.combo_id IS NULL, 'ITEM', 'COMBO') AS kind, IFNULL(bi.item_id, bi.combo_id) AS ref_id,
         IFNULL(bi.item_code, '') AS code, bi.item_name AS name, IFNULL(bi.unit_code, '') AS unit_code, bi.allow_decimal,
         bi.qty, bi.rate, bi.gst_pct AS gst_percent, bi.price_includes_gst, bi.line_amount AS amount,
         bi.discount_share AS discount, bi.taxable_amount AS taxable, bi.cgst + bi.sgst AS gst_amount,
         bi.cgst, bi.sgst, bi.line_total AS total
    FROM bill_items bi
   WHERE bi.bill_id = p_id
   ORDER BY bi.line_no;

  SELECT bp.payment_mode AS mode, bp.amount, bp.reference_no AS reference, bp.cash_received, bp.change_returned
    FROM bill_payments bp
   WHERE bp.bill_id = p_id
   ORDER BY bp.id;

  SELECT h.to_status AS status, h.changed_at AS `at`,
         COALESCE(e.full_name, IF(u.id IS NOT NULL AND u.employee_id IS NULL, 'Administrator', u.username), 'System') AS `by`,
         h.remarks AS note
    FROM bill_status_history h
    LEFT JOIN users u ON u.id = h.changed_by
    LEFT JOIN employees e ON e.id = u.employee_id
   WHERE h.bill_id = p_id
   ORDER BY h.id;
END
