-- sp_customer_get_by_mobile
-- Purpose : Returning-customer lookup at the billing counter.
-- Params  : p_mobile
-- Results : (1) id, mobile, name, total_spent, visit_count, last_visit_at
-- Errors  : 45404 no customer with this mobile
CREATE PROCEDURE sp_customer_get_by_mobile(IN p_mobile VARCHAR(10))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM customers WHERE mobile = TRIM(p_mobile)) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Customer not found';
  END IF;

  SELECT id, mobile, IFNULL(customer_name, '') AS name, total_spent, visit_count, last_visit_at
    FROM customers
   WHERE mobile = TRIM(p_mobile);
END
