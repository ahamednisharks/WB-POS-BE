-- sp_salary_payment_delete
-- Purpose : Soft-deletes a PENDING salary record (paid ones are final).
-- Params  : p_id, p_user_id
-- Results : (1) id, message, deleted
-- Errors  : 45000 already paid, 45404 not found
CREATE PROCEDURE sp_salary_payment_delete(IN p_id INT, IN p_user_id INT)
BEGIN
  DECLARE v_status VARCHAR(10) DEFAULT NULL;

  SELECT pay_status INTO v_status FROM salary_payments WHERE id = p_id AND is_deleted = 0;
  IF v_status IS NULL THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Salary payment not found';
  END IF;
  IF v_status = 'PAID' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Paid salary records cannot be deleted';
  END IF;

  UPDATE salary_payments SET is_deleted = 1, updated_by = p_user_id, updated_at = NOW() WHERE id = p_id;
  CALL sp_util_audit(p_user_id, 'DELETE', 'salary_payments', p_id, NULL, NULL);
  SELECT p_id AS id, 'Salary record deleted successfully' AS message, 1 AS deleted;
END
