-- sp_day_close_save
-- Purpose : Records the day close. Cash figures are recomputed from transactions (client values ignored):
--           expected = opening + cash sales - cash refunds - cash outs; difference = counted - expected.
--           Remarks are required when there is a difference. One close per user per day; only an ADMIN may re-save.
--           Cashiers can only close today.
-- Params  : p_date, p_opening_cash, p_counted_cash, p_remarks, p_user_id, p_role
-- Results : (1) id, message
-- Errors  : 45000 validation, 45409 already closed
CREATE PROCEDURE sp_day_close_save(
  IN p_date         DATE,
  IN p_opening_cash DECIMAL(12,2),
  IN p_counted_cash DECIMAL(12,2),
  IN p_remarks      VARCHAR(255),
  IN p_user_id      INT,
  IN p_role         VARCHAR(10)
)
BEGIN
  DECLARE v_date     DATE DEFAULT IFNULL(p_date, CURDATE());
  DECLARE v_opening  DECIMAL(12,2) DEFAULT ROUND(GREATEST(IFNULL(p_opening_cash, 0), 0), 2);
  DECLARE v_counted  DECIMAL(12,2) DEFAULT ROUND(p_counted_cash, 2);
  DECLARE v_sales    DECIMAL(12,2);
  DECLARE v_refunds  DECIMAL(12,2);
  DECLARE v_outs     DECIMAL(12,2);
  DECLARE v_expected DECIMAL(12,2);
  DECLARE v_diff     DECIMAL(12,2);
  DECLARE v_id       INT DEFAULT NULL;

  IF v_date > CURDATE() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'date::Date cannot be in the future';
  END IF;
  IF p_role = 'CASHIER' AND v_date <> CURDATE() THEN
    SIGNAL SQLSTATE '45403' SET MESSAGE_TEXT = 'date::Cashiers can only close today';
  END IF;
  IF v_counted IS NULL OR v_counted < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'countedCash::Counted cash is required';
  END IF;

  SELECT MAX(id) INTO v_id FROM day_closings WHERE close_date = v_date AND cashier_id = p_user_id;
  IF v_id IS NOT NULL AND p_role <> 'ADMIN' THEN
    SIGNAL SQLSTATE '45409' SET MESSAGE_TEXT = 'The day is already closed. Ask Admin to re-close it.';
  END IF;

  CALL sp_day_close_figures(v_date, p_user_id, p_role, v_sales, v_refunds, v_outs);
  SET v_expected = v_opening + v_sales - v_refunds - v_outs;
  SET v_diff = v_counted - v_expected;

  IF v_diff <> 0 AND TRIM(IFNULL(p_remarks, '')) = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'remarks::Remarks are required when there is a difference';
  END IF;

  IF v_id IS NULL THEN
    INSERT INTO day_closings (close_date, cashier_id, opening_cash, cash_sales, cash_refunds, cash_outs, expected_cash,
                              counted_cash, difference, remarks, created_by)
    VALUES (v_date, p_user_id, v_opening, v_sales, v_refunds, v_outs, v_expected, v_counted, v_diff,
            NULLIF(TRIM(p_remarks), ''), p_user_id);
    SET v_id = LAST_INSERT_ID();
  ELSE
    UPDATE day_closings
       SET opening_cash = v_opening, cash_sales = v_sales, cash_refunds = v_refunds, cash_outs = v_outs,
           expected_cash = v_expected, counted_cash = v_counted, difference = v_diff,
           remarks = NULLIF(TRIM(p_remarks), ''), updated_by = p_user_id, updated_at = NOW()
     WHERE id = v_id;
    CALL sp_util_audit(p_user_id, 'RECLOSE', 'day_closings', v_id, NULL, JSON_OBJECT('countedCash', v_counted, 'difference', v_diff));
  END IF;

  SELECT v_id AS id, IF(v_diff = 0, 'Day closed - cash tallies', CONCAT('Day closed with a difference of ', v_diff)) AS message;
END
