-- sp_day_close_list
-- Purpose : Day-close history (ADMIN).
-- Params  : p_from DATE, p_to DATE, p_cashier_id, p_page, p_limit
-- Results : (1) rows, (2) total
-- Errors  : none
CREATE PROCEDURE sp_day_close_list(IN p_from DATE, IN p_to DATE, IN p_cashier_id INT, IN p_page INT, IN p_limit INT)
BEGIN
  DECLARE v_limit  INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 10), 1), 1000);
  DECLARE v_offset INT DEFAULT (GREATEST(IFNULL(p_page, 1), 1) - 1) * v_limit;

  SELECT d.id, d.close_date AS date, d.opening_cash, d.cash_sales, d.cash_refunds, d.cash_outs, d.expected_cash,
         d.counted_cash, d.difference, IFNULL(d.remarks, '') AS remarks, d.cashier_id AS closed_by_id,
         COALESCE(e.full_name, IF(u.employee_id IS NULL, 'Administrator', u.username)) AS closed_by_name,
         d.created_at, IFNULL(d.updated_at, d.created_at) AS updated_at
    FROM day_closings d
    JOIN users u ON u.id = d.cashier_id
    LEFT JOIN employees e ON e.id = u.employee_id
   WHERE (p_from IS NULL OR d.close_date >= p_from)
     AND (p_to IS NULL OR d.close_date <= p_to)
     AND (p_cashier_id IS NULL OR d.cashier_id = p_cashier_id)
   ORDER BY d.close_date DESC, d.id DESC
   LIMIT v_limit OFFSET v_offset;

  SELECT COUNT(*) AS total
    FROM day_closings d
   WHERE (p_from IS NULL OR d.close_date >= p_from)
     AND (p_to IS NULL OR d.close_date <= p_to)
     AND (p_cashier_id IS NULL OR d.cashier_id = p_cashier_id);
END
