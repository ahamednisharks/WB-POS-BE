-- sp_preorder_get
-- Purpose : One pre-order for the detail / edit screen and the order slip. Visible to every user (an order booked by
--           one cashier is often delivered by another).
-- Params  : p_id
-- Results : (1) header (refund_mode from the REFUND transaction), (2) lines (master_rate = Actual Price,
--           rate = Item Price, rate_diff = rate - master_rate), (3) payments (at_delivery = collected with the bill)
-- Errors  : 45404 not found
CREATE PROCEDURE sp_preorder_get(IN p_id INT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pre_orders WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Pre-order not found';
  END IF;

  SELECT p.id, p.order_no, p.order_date, p.customer_mobile, p.customer_name, IFNULL(p.alt_mobile, '') AS alt_mobile,
         p.delivery_at, p.delivery_type, IFNULL(p.delivery_address, '') AS delivery_address, p.delivery_charge,
         p.item_count, p.sub_total, p.discount_amount, p.taxable_amount, p.cgst, p.sgst, p.cgst + p.sgst AS total_gst,
         p.round_off, p.grand_total, p.paid_amount, p.grand_total - p.paid_amount AS balance,
         p.order_status AS status, p.bill_id, b.bill_no, p.ready_at, p.delivered_at,
         p.cancel_reason, p.refund_amount,
         (SELECT MAX(t.payment_mode) FROM transactions t WHERE t.pre_order_id = p.id AND t.txn_type = 'REFUND') AS refund_mode,
         p.cancelled_at, p.booked_by,
         COALESCE(e.full_name, IF(u.employee_id IS NULL AND u.role = 'ADMIN', 'Administrator', u.username)) AS booked_by_name,
         p.created_at, IFNULL(p.updated_at, p.created_at) AS updated_at
    FROM pre_orders p
    JOIN users u ON u.id = p.booked_by
    LEFT JOIN employees e ON e.id = u.employee_id
    LEFT JOIN bills b ON b.id = p.bill_id
   WHERE p.id = p_id;

  SELECT li.item_id, IFNULL(li.item_code, '') AS item_code, li.item_name, IFNULL(li.category_name, '') AS category_name,
         IFNULL(li.unit_code, '') AS unit_code, li.allow_decimal, li.qty, li.master_rate, li.rate,
         li.rate - li.master_rate AS rate_diff, li.gst_pct AS gst_percent, li.price_includes_gst,
         li.line_amount AS amount, li.discount_share AS discount, li.taxable_amount AS taxable,
         li.cgst + li.sgst AS gst_amount, li.cgst, li.sgst, li.line_total AS total,
         IFNULL(li.notes, '') AS notes, li.design_url
    FROM pre_order_items li
   WHERE li.pre_order_id = p_id
   ORDER BY li.line_no;

  SELECT pp.id, pp.paid_at, pp.payment_mode AS mode, pp.amount, pp.reference_no AS reference, t.txn_no,
         t.bill_id IS NOT NULL AS at_delivery,
         COALESCE(e.full_name, IF(u.employee_id IS NULL AND u.role = 'ADMIN', 'Administrator', u.username)) AS received_by_name
    FROM pre_order_payments pp
    JOIN users u ON u.id = pp.received_by
    LEFT JOIN employees e ON e.id = u.employee_id
    LEFT JOIN transactions t ON t.id = pp.txn_id
   WHERE pp.pre_order_id = p_id
   ORDER BY pp.id;
END
