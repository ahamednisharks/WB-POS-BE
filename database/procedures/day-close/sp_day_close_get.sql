-- sp_day_close_get
-- Purpose : One day-close record (for the printed slip). Cashiers can only read their own.
-- Params  : p_id, p_user_id, p_role
-- Results : (1) row
-- Errors  : 45404 not found
CREATE PROCEDURE sp_day_close_get(IN p_id INT, IN p_user_id INT, IN p_role VARCHAR(10))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM day_closings WHERE id = p_id AND (p_role <> 'CASHIER' OR cashier_id = p_user_id)) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Day close not found';
  END IF;

  SELECT d.id, d.close_date AS date, d.opening_cash, d.cash_sales, d.cash_refunds, d.cash_outs, d.expected_cash,
         d.counted_cash, d.difference, IFNULL(d.remarks, '') AS remarks, d.cashier_id AS closed_by_id,
         COALESCE(e.full_name, IF(u.employee_id IS NULL, 'Administrator', u.username)) AS closed_by_name,
         d.created_at, IFNULL(d.updated_at, d.created_at) AS updated_at
    FROM day_closings d
    JOIN users u ON u.id = d.cashier_id
    LEFT JOIN employees e ON e.id = u.employee_id
   WHERE d.id = p_id;
END
