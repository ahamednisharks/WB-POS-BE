-- sp_day_close_figures
-- Purpose : Shared cash figures for a day (no result set). A CASHIER covers only their own till;
--           an ADMIN closes the whole shop (all users).
-- Params  : p_date, p_user_id, p_role, OUT p_cash_sales, OUT p_cash_refunds, OUT p_cash_outs
-- Results : none
-- Errors  : none
CREATE PROCEDURE sp_day_close_figures(
  IN  p_date         DATE,
  IN  p_user_id      INT,
  IN  p_role         VARCHAR(10),
  OUT p_cash_sales   DECIMAL(12,2),
  OUT p_cash_refunds DECIMAL(12,2),
  OUT p_cash_outs    DECIMAL(12,2)
)
BEGIN
  SELECT IFNULL(SUM(IF(txn_type = 'PAYMENT', amount, 0)), 0),
         IFNULL(SUM(IF(txn_type = 'REFUND', amount, 0)), 0),
         IFNULL(SUM(IF(txn_type = 'CASH_OUT', amount, 0)), 0)
    INTO p_cash_sales, p_cash_refunds, p_cash_outs
    FROM transactions
   WHERE payment_mode = 'CASH'
     AND txn_date >= p_date AND txn_date < p_date + INTERVAL 1 DAY
     AND (p_role <> 'CASHIER' OR user_id = p_user_id);
END
