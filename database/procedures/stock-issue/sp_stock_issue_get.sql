-- sp_stock_issue_get
-- Purpose : One stock issue with its lines.
-- Params  : p_id
-- Results : (1) header (is_editable = posted and created today; the API also checks the creator / admin rule),
--           (2) lines with the item's current stock (so an edit form can show what is available)
-- Errors  : 45404 not found
CREATE PROCEDURE sp_stock_issue_get(IN p_id INT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM stock_issues WHERE id = p_id) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Stock issue not found';
  END IF;

  SELECT si.id, si.issue_no, si.issue_date, si.remarks, si.item_count, si.total_value,
         si.issue_status AS status, si.issued_by,
         COALESCE(e.full_name, IF(u.employee_id IS NULL AND u.role = 'ADMIN', 'Administrator', u.username)) AS issued_by_name,
         si.cancel_reason, si.cancelled_at,
         COALESCE(ce.full_name, IF(cu.employee_id IS NULL AND cu.role = 'ADMIN', 'Administrator', cu.username)) AS cancelled_by_name,
         IF(si.issue_status = 'POSTED' AND DATE(si.created_at) = CURDATE(), 1, 0) AS is_editable,
         si.created_at, IFNULL(si.updated_at, si.created_at) AS updated_at
    FROM stock_issues si
    JOIN users u            ON u.id = si.issued_by
    LEFT JOIN employees e   ON e.id = u.employee_id
    LEFT JOIN users cu      ON cu.id = si.cancelled_by
    LEFT JOIN employees ce  ON ce.id = cu.employee_id
   WHERE si.id = p_id;

  SELECT sii.item_id, i.item_code, i.item_name, u.short_code AS unit_code, u.allow_decimal,
         sii.qty, sii.reason, sii.rate, sii.amount, sii.remarks, i.current_stock
    FROM stock_issue_items sii
    JOIN items i ON i.id = sii.item_id
    JOIN units u ON u.id = i.unit_id
   WHERE sii.si_id = p_id
   ORDER BY sii.line_no;
END
