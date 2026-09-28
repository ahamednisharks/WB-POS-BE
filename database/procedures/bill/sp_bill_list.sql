-- sp_bill_list
-- Purpose : Paged bill list (orders screen). Role-scoped: a CASHIER only ever sees their own bills.
-- Params  : p_from DATE, p_to DATE, p_status (HELD|COMPLETED|CANCELLED|NULL), p_cashier_id, p_payment_mode
--           (CASH|UPI|CARD|SPLIT|NULL), p_search (bill no, customer mobile / name),
--           p_sort_by (billNo|billDate|itemCount|grandTotal|cashierName|status|createdAt), p_sort_dir, p_page, p_limit,
--           p_user_id, p_role
-- Results : (1) rows (with payments JSON), (2) total
-- Errors  : none
CREATE PROCEDURE sp_bill_list(
  IN p_from         DATE,
  IN p_to           DATE,
  IN p_status       VARCHAR(10),
  IN p_cashier_id   INT,
  IN p_payment_mode VARCHAR(10),
  IN p_search       VARCHAR(100),
  IN p_sort_by      VARCHAR(30),
  IN p_sort_dir     VARCHAR(4),
  IN p_page         INT,
  IN p_limit        INT,
  IN p_user_id      INT,
  IN p_role         VARCHAR(10)
)
BEGIN
  DECLARE v_limit   INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 10), 1), 1000);
  DECLARE v_offset  INT DEFAULT (GREATEST(IFNULL(p_page, 1), 1) - 1) * v_limit;
  DECLARE v_cashier INT DEFAULT IF(p_role = 'CASHIER', p_user_id, p_cashier_id);

  SELECT b.id, b.bill_no, b.bill_date, b.cashier_id,
         COALESCE(e.full_name, IF(u.employee_id IS NULL, 'Administrator', u.username)) AS cashier_name,
         IFNULL(b.customer_mobile, '') AS customer_mobile, IFNULL(b.customer_name, '') AS customer_name,
         b.item_count, b.discount_type, b.discount_value, b.sub_total, b.discount_amount, b.taxable_amount,
         b.cgst, b.sgst, b.cgst + b.sgst AS total_gst, b.round_off, b.grand_total, b.payment_mode,
         b.bill_status AS status, b.cancel_reason,
         (SELECT JSON_ARRAYAGG(JSON_OBJECT('mode', bp.payment_mode, 'amount', bp.amount, 'reference', bp.reference_no))
            FROM bill_payments bp WHERE bp.bill_id = b.id) AS payments,
         b.created_at, IFNULL(b.updated_at, b.created_at) AS updated_at
    FROM bills b
    JOIN users u ON u.id = b.cashier_id
    LEFT JOIN employees e ON e.id = u.employee_id
   WHERE b.is_deleted = 0
     AND (p_from IS NULL OR b.bill_date >= p_from)
     AND (p_to IS NULL OR b.bill_date < p_to + INTERVAL 1 DAY)
     AND (IFNULL(p_status, '') = '' OR b.bill_status = p_status)
     AND (v_cashier IS NULL OR b.cashier_id = v_cashier)
     AND (IFNULL(p_payment_mode, '') = ''
          OR b.payment_mode = p_payment_mode
          OR (p_payment_mode <> 'SPLIT' AND b.payment_mode = 'SPLIT'
              AND EXISTS (SELECT 1 FROM bill_payments bp WHERE bp.bill_id = b.id AND bp.payment_mode = p_payment_mode)))
     AND (IFNULL(p_search, '') = ''
          OR b.bill_no LIKE CONCAT('%', p_search, '%')
          OR b.customer_mobile LIKE CONCAT('%', p_search, '%')
          OR b.customer_name LIKE CONCAT('%', p_search, '%'))
   ORDER BY
     CASE WHEN p_sort_by = 'billNo'      AND p_sort_dir = 'asc'  THEN b.bill_no END ASC,
     CASE WHEN p_sort_by = 'billNo'      AND p_sort_dir = 'desc' THEN b.bill_no END DESC,
     CASE WHEN p_sort_by = 'billDate'    AND p_sort_dir = 'asc'  THEN b.bill_date END ASC,
     CASE WHEN p_sort_by = 'billDate'    AND p_sort_dir = 'desc' THEN b.bill_date END DESC,
     CASE WHEN p_sort_by = 'itemCount'   AND p_sort_dir = 'asc'  THEN b.item_count END ASC,
     CASE WHEN p_sort_by = 'itemCount'   AND p_sort_dir = 'desc' THEN b.item_count END DESC,
     CASE WHEN p_sort_by = 'grandTotal'  AND p_sort_dir = 'asc'  THEN b.grand_total END ASC,
     CASE WHEN p_sort_by = 'grandTotal'  AND p_sort_dir = 'desc' THEN b.grand_total END DESC,
     CASE WHEN p_sort_by = 'cashierName' AND p_sort_dir = 'asc'  THEN COALESCE(e.full_name, u.username) END ASC,
     CASE WHEN p_sort_by = 'cashierName' AND p_sort_dir = 'desc' THEN COALESCE(e.full_name, u.username) END DESC,
     CASE WHEN p_sort_by = 'status'      AND p_sort_dir = 'asc'  THEN b.bill_status END ASC,
     CASE WHEN p_sort_by = 'status'      AND p_sort_dir = 'desc' THEN b.bill_status END DESC,
     CASE WHEN p_sort_by = 'createdAt'   AND p_sort_dir = 'asc'  THEN b.id END ASC,
     b.bill_date DESC, b.id DESC
   LIMIT v_limit OFFSET v_offset;

  SELECT COUNT(*) AS total
    FROM bills b
   WHERE b.is_deleted = 0
     AND (p_from IS NULL OR b.bill_date >= p_from)
     AND (p_to IS NULL OR b.bill_date < p_to + INTERVAL 1 DAY)
     AND (IFNULL(p_status, '') = '' OR b.bill_status = p_status)
     AND (v_cashier IS NULL OR b.cashier_id = v_cashier)
     AND (IFNULL(p_payment_mode, '') = ''
          OR b.payment_mode = p_payment_mode
          OR (p_payment_mode <> 'SPLIT' AND b.payment_mode = 'SPLIT'
              AND EXISTS (SELECT 1 FROM bill_payments bp WHERE bp.bill_id = b.id AND bp.payment_mode = p_payment_mode)))
     AND (IFNULL(p_search, '') = ''
          OR b.bill_no LIKE CONCAT('%', p_search, '%')
          OR b.customer_mobile LIKE CONCAT('%', p_search, '%')
          OR b.customer_name LIKE CONCAT('%', p_search, '%'));
END
