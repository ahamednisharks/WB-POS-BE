-- sp_bill_held_list
-- Purpose : Held (parked) bills, newest first. Cashiers see only their own.
-- Params  : p_user_id, p_role
-- Results : (1) rows (id, bill_no, bill_date, cashier, customer, item_count, grand_total, lines JSON)
-- Errors  : none
CREATE PROCEDURE sp_bill_held_list(IN p_user_id INT, IN p_role VARCHAR(10))
BEGIN
  SELECT b.id, b.bill_no, b.bill_date, b.cashier_id,
         COALESCE(e.full_name, IF(u.employee_id IS NULL, 'Administrator', u.username)) AS cashier_name,
         IFNULL(b.customer_mobile, '') AS customer_mobile, IFNULL(b.customer_name, '') AS customer_name,
         b.item_count, b.sub_total, b.discount_amount, b.grand_total, b.bill_status AS status,
         (SELECT JSON_ARRAYAGG(JSON_OBJECT('name', bi.item_name, 'qty', bi.qty, 'total', bi.line_total))
            FROM bill_items bi WHERE bi.bill_id = b.id) AS lines_summary
    FROM bills b
    JOIN users u ON u.id = b.cashier_id
    LEFT JOIN employees e ON e.id = u.employee_id
   WHERE b.is_deleted = 0 AND b.bill_status = 'HELD'
     AND (IFNULL(p_role, '') <> 'CASHIER' OR b.cashier_id = p_user_id)
   ORDER BY b.bill_date DESC, b.id DESC
   LIMIT 200;
END
