-- sp_transaction_list
-- Purpose : Till movements (bill payments, refunds, cash paid out) with a summary for the same filter.
--           Role-scoped: a CASHIER always gets only their own transactions for today, whatever the filters say.
-- Params  : p_from DATE, p_to DATE, p_mode (CASH|UPI|CARD|BANK|CHEQUE|NULL), p_type (PAYMENT|REFUND|CASH_OUT|NULL),
--           p_cashier_id, p_search (txn no, bill no, reference, remarks, cashier),
--           p_sort_by (txnNo|txnDate|billNo|type|mode|amount|cashierName), p_sort_dir, p_page, p_limit, p_user_id, p_role
-- Results : (1) rows, (2) total,
--           (3) summary: total_received, cash, upi, card, refunds, cash_refunds, cash_outs, net
-- Errors  : none
CREATE PROCEDURE sp_transaction_list(
  IN p_from       DATE,
  IN p_to         DATE,
  IN p_mode       VARCHAR(10),
  IN p_type       VARCHAR(10),
  IN p_cashier_id INT,
  IN p_search     VARCHAR(100),
  IN p_sort_by    VARCHAR(30),
  IN p_sort_dir   VARCHAR(4),
  IN p_page       INT,
  IN p_limit      INT,
  IN p_user_id    INT,
  IN p_role       VARCHAR(10)
)
BEGIN
  DECLARE v_limit   INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 10), 1), 1000);
  DECLARE v_offset  INT DEFAULT (GREATEST(IFNULL(p_page, 1), 1) - 1) * v_limit;
  DECLARE v_cashier INT DEFAULT IF(p_role = 'CASHIER', p_user_id, p_cashier_id);
  DECLARE v_from    DATE DEFAULT IF(p_role = 'CASHIER', CURDATE(), p_from);
  DECLARE v_to      DATE DEFAULT IF(p_role = 'CASHIER', CURDATE(), p_to);

  SELECT t.id, t.txn_no, t.txn_date, t.txn_type AS type, t.payment_mode AS mode, t.amount,
         t.reference_no AS reference, t.bill_id, b.bill_no, t.purchase_entry_id, t.salary_payment_id,
         t.remarks AS note, t.user_id AS cashier_id,
         COALESCE(e.full_name, IF(u.employee_id IS NULL, 'Administrator', u.username)) AS cashier_name
    FROM transactions t
    JOIN users u ON u.id = t.user_id
    LEFT JOIN employees e ON e.id = u.employee_id
    LEFT JOIN bills b ON b.id = t.bill_id
   WHERE (v_from IS NULL OR t.txn_date >= v_from)
     AND (v_to IS NULL OR t.txn_date < v_to + INTERVAL 1 DAY)
     AND (v_cashier IS NULL OR t.user_id = v_cashier)
     AND (IFNULL(p_mode, '') = '' OR t.payment_mode = p_mode)
     AND (IFNULL(p_type, '') = '' OR t.txn_type = p_type)
     AND (IFNULL(p_search, '') = ''
          OR t.txn_no LIKE CONCAT('%', p_search, '%')
          OR b.bill_no LIKE CONCAT('%', p_search, '%')
          OR t.reference_no LIKE CONCAT('%', p_search, '%')
          OR t.remarks LIKE CONCAT('%', p_search, '%')
          OR e.full_name LIKE CONCAT('%', p_search, '%'))
   ORDER BY
     CASE WHEN p_sort_by = 'txnNo'       AND p_sort_dir = 'asc'  THEN t.txn_no END ASC,
     CASE WHEN p_sort_by = 'txnNo'       AND p_sort_dir = 'desc' THEN t.txn_no END DESC,
     CASE WHEN p_sort_by = 'txnDate'     AND p_sort_dir = 'asc'  THEN t.txn_date END ASC,
     CASE WHEN p_sort_by = 'txnDate'     AND p_sort_dir = 'desc' THEN t.txn_date END DESC,
     CASE WHEN p_sort_by = 'billNo'      AND p_sort_dir = 'asc'  THEN b.bill_no END ASC,
     CASE WHEN p_sort_by = 'billNo'      AND p_sort_dir = 'desc' THEN b.bill_no END DESC,
     CASE WHEN p_sort_by = 'type'        AND p_sort_dir = 'asc'  THEN t.txn_type END ASC,
     CASE WHEN p_sort_by = 'type'        AND p_sort_dir = 'desc' THEN t.txn_type END DESC,
     CASE WHEN p_sort_by = 'mode'        AND p_sort_dir = 'asc'  THEN t.payment_mode END ASC,
     CASE WHEN p_sort_by = 'mode'        AND p_sort_dir = 'desc' THEN t.payment_mode END DESC,
     CASE WHEN p_sort_by = 'amount'      AND p_sort_dir = 'asc'  THEN t.amount END ASC,
     CASE WHEN p_sort_by = 'amount'      AND p_sort_dir = 'desc' THEN t.amount END DESC,
     CASE WHEN p_sort_by = 'cashierName' AND p_sort_dir = 'asc'  THEN COALESCE(e.full_name, u.username) END ASC,
     CASE WHEN p_sort_by = 'cashierName' AND p_sort_dir = 'desc' THEN COALESCE(e.full_name, u.username) END DESC,
     t.txn_date DESC, t.id DESC
   LIMIT v_limit OFFSET v_offset;

  SELECT COUNT(*) AS total
    FROM transactions t
    JOIN users u ON u.id = t.user_id
    LEFT JOIN employees e ON e.id = u.employee_id
    LEFT JOIN bills b ON b.id = t.bill_id
   WHERE (v_from IS NULL OR t.txn_date >= v_from)
     AND (v_to IS NULL OR t.txn_date < v_to + INTERVAL 1 DAY)
     AND (v_cashier IS NULL OR t.user_id = v_cashier)
     AND (IFNULL(p_mode, '') = '' OR t.payment_mode = p_mode)
     AND (IFNULL(p_type, '') = '' OR t.txn_type = p_type)
     AND (IFNULL(p_search, '') = ''
          OR t.txn_no LIKE CONCAT('%', p_search, '%')
          OR b.bill_no LIKE CONCAT('%', p_search, '%')
          OR t.reference_no LIKE CONCAT('%', p_search, '%')
          OR t.remarks LIKE CONCAT('%', p_search, '%')
          OR e.full_name LIKE CONCAT('%', p_search, '%'));

  SELECT IFNULL(SUM(IF(x.txn_type = 'PAYMENT', x.amount, 0)), 0) AS total_received,
         IFNULL(SUM(IF(x.txn_type = 'PAYMENT' AND x.payment_mode = 'CASH', x.amount, 0)), 0) AS cash,
         IFNULL(SUM(IF(x.txn_type = 'PAYMENT' AND x.payment_mode = 'UPI', x.amount, 0)), 0) AS upi,
         IFNULL(SUM(IF(x.txn_type = 'PAYMENT' AND x.payment_mode = 'CARD', x.amount, 0)), 0) AS card,
         IFNULL(SUM(IF(x.txn_type = 'REFUND', x.amount, 0)), 0) AS refunds,
         IFNULL(SUM(IF(x.txn_type = 'REFUND' AND x.payment_mode = 'CASH', x.amount, 0)), 0) AS cash_refunds,
         IFNULL(SUM(IF(x.txn_type = 'CASH_OUT', x.amount, 0)), 0) AS cash_outs,
         IFNULL(SUM(CASE x.txn_type WHEN 'PAYMENT' THEN x.amount ELSE -x.amount END), 0) AS net
    FROM (
      SELECT t.txn_type, t.payment_mode, t.amount
        FROM transactions t
        JOIN users u ON u.id = t.user_id
        LEFT JOIN employees e ON e.id = u.employee_id
        LEFT JOIN bills b ON b.id = t.bill_id
       WHERE (v_from IS NULL OR t.txn_date >= v_from)
         AND (v_to IS NULL OR t.txn_date < v_to + INTERVAL 1 DAY)
         AND (v_cashier IS NULL OR t.user_id = v_cashier)
         AND (IFNULL(p_mode, '') = '' OR t.payment_mode = p_mode)
         AND (IFNULL(p_type, '') = '' OR t.txn_type = p_type)
         AND (IFNULL(p_search, '') = ''
              OR t.txn_no LIKE CONCAT('%', p_search, '%')
              OR b.bill_no LIKE CONCAT('%', p_search, '%')
              OR t.reference_no LIKE CONCAT('%', p_search, '%')
              OR t.remarks LIKE CONCAT('%', p_search, '%')
              OR e.full_name LIKE CONCAT('%', p_search, '%'))
    ) AS x;
END
