-- sp_transaction_export
-- Purpose : Same filters as sp_transaction_list without paging (capped at 50,000 rows) for Excel / PDF export.
-- Params  : p_from, p_to, p_mode, p_type, p_cashier_id, p_search, p_user_id, p_role
-- Results : (1) rows (oldest first), (2) summary (same columns as sp_transaction_list)
-- Errors  : none
CREATE PROCEDURE sp_transaction_export(
  IN p_from       DATE,
  IN p_to         DATE,
  IN p_mode       VARCHAR(10),
  IN p_type       VARCHAR(10),
  IN p_cashier_id INT,
  IN p_search     VARCHAR(100),
  IN p_user_id    INT,
  IN p_role       VARCHAR(10)
)
BEGIN
  DECLARE v_cashier INT DEFAULT IF(p_role = 'CASHIER', p_user_id, p_cashier_id);
  DECLARE v_from    DATE DEFAULT IF(p_role = 'CASHIER', CURDATE(), p_from);
  DECLARE v_to      DATE DEFAULT IF(p_role = 'CASHIER', CURDATE(), p_to);

  SELECT t.txn_no, t.txn_date, t.txn_type AS type, t.payment_mode AS mode, t.amount, b.bill_no,
         t.reference_no AS reference, t.remarks AS note,
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
          OR t.remarks LIKE CONCAT('%', p_search, '%'))
   ORDER BY t.txn_date, t.id
   LIMIT 50000;

  SELECT IFNULL(SUM(IF(t.txn_type = 'PAYMENT', t.amount, 0)), 0) AS total_received,
         IFNULL(SUM(IF(t.txn_type = 'PAYMENT' AND t.payment_mode = 'CASH', t.amount, 0)), 0) AS cash,
         IFNULL(SUM(IF(t.txn_type = 'PAYMENT' AND t.payment_mode = 'UPI', t.amount, 0)), 0) AS upi,
         IFNULL(SUM(IF(t.txn_type = 'PAYMENT' AND t.payment_mode = 'CARD', t.amount, 0)), 0) AS card,
         IFNULL(SUM(IF(t.txn_type = 'REFUND', t.amount, 0)), 0) AS refunds,
         IFNULL(SUM(IF(t.txn_type = 'REFUND' AND t.payment_mode = 'CASH', t.amount, 0)), 0) AS cash_refunds,
         IFNULL(SUM(IF(t.txn_type = 'CASH_OUT', t.amount, 0)), 0) AS cash_outs,
         IFNULL(SUM(CASE t.txn_type WHEN 'PAYMENT' THEN t.amount ELSE -t.amount END), 0) AS net
    FROM transactions t
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
          OR t.remarks LIKE CONCAT('%', p_search, '%'));
END
