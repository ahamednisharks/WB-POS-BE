-- sp_combo_get
-- Purpose : One combo with its component items.
-- Params  : p_id
-- Results : (1) header, (2) items (item_id, item_name, unit_code, qty, price, current_price)
-- Errors  : 45404 not found
CREATE PROCEDURE sp_combo_get(IN p_id INT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM combos WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Combo not found';
  END IF;

  SELECT c.id, c.combo_name AS name, c.actual_price, c.combo_price, c.actual_price - c.combo_price AS savings,
         c.gst_pct AS gst_percent, c.valid_from, c.valid_to, c.image_url AS image,
         IF(c.status = 1, 'ACTIVE', 'INACTIVE') AS status,
         c.created_at, IFNULL(c.updated_at, c.created_at) AS updated_at
    FROM combos c
   WHERE c.id = p_id;

  SELECT ci.item_id, i.item_name, u.short_code AS unit_code, ci.qty, ci.price, i.selling_price AS current_price
    FROM combo_items ci
    JOIN items i ON i.id = ci.item_id
    JOIN units u ON u.id = i.unit_id
   WHERE ci.combo_id = p_id
   ORDER BY ci.id;
END
