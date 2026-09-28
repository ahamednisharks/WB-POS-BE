-- sp_salary_payment_mark_paid
-- Purpose : Marks a PENDING salary as PAID (advance recovery oldest-first, CASH_OUT when paid in cash).
-- Params  : p_id, p_payment_date, p_payment_mode (CASH|BANK|UPI), p_user_id
-- Results : (1) id, message
-- Errors  : 45000 validation / already paid, 45404 not found
CREATE PROCEDURE sp_salary_payment_mark_paid(
  IN p_id           INT,
  IN p_payment_date DATE,
  IN p_payment_mode VARCHAR(10),
  IN p_user_id      INT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  START TRANSACTION;
  CALL sp_salary_payment_post_paid(p_id, p_payment_date, p_payment_mode, p_user_id);
  COMMIT;

  SELECT p_id AS id, 'Salary marked as paid' AS message;
END
