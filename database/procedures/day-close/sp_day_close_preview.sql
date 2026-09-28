-- sp_day_close_preview
-- Purpose : Figures for the day-close dialog: suggested opening cash (last counted cash), cash sales, refunds,
--           cash paid out and expected cash; plus the existing close for that day, if any.
-- Params  : p_date (NULL = today), p_user_id, p_role
-- Results : (1) date, opening_cash, cash_sales, cash_refunds, cash_outs, expected_cash, existing_id, already_closed
-- Errors  : 45000 future date
CREATE PROCEDURE sp_day_close_preview(IN p_date DATE, IN p_user_id INT, IN p_role VARCHAR(10))
BEGIN
  DECLARE v_date     DATE DEFAULT IFNULL(p_date, CURDATE());
  DECLARE v_opening  DECIMAL(12,2) DEFAULT 0;
  DECLARE v_sales    DECIMAL(12,2);
  DECLARE v_refunds  DECIMAL(12,2);
  DECLARE v_outs     DECIMAL(12,2);
  DECLARE v_existing INT DEFAULT NULL;

  IF v_date > CURDATE() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'date::Date cannot be in the future';
  END IF;

  SELECT counted_cash INTO v_opening
    FROM day_closings
   WHERE cashier_id = p_user_id AND close_date < v_date
   ORDER BY close_date DESC
   LIMIT 1;

  SELECT MAX(id) INTO v_existing FROM day_closings WHERE close_date = v_date AND cashier_id = p_user_id;

  CALL sp_day_close_figures(v_date, p_user_id, p_role, v_sales, v_refunds, v_outs);

  SELECT v_date AS date, IFNULL(v_opening, 0) AS opening_cash, v_sales AS cash_sales, v_refunds AS cash_refunds,
         v_outs AS cash_outs, IFNULL(v_opening, 0) + v_sales - v_refunds - v_outs AS expected_cash,
         v_existing AS existing_id, IF(v_existing IS NULL, 0, 1) AS already_closed;
END
