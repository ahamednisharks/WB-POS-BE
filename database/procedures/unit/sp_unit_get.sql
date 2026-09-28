-- sp_unit_get
-- Purpose : One unit.
-- Params  : p_id
-- Results : (1) unit row
-- Errors  : 45404 not found
CREATE PROCEDURE sp_unit_get(IN p_id INT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM units WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Unit not found';
  END IF;

  SELECT u.id, u.unit_name AS name, u.short_code, u.allow_decimal,
         IF(u.status = 1, 'ACTIVE', 'INACTIVE') AS status,
         (SELECT COUNT(*) FROM items i WHERE i.unit_id = u.id AND i.is_deleted = 0) AS item_count,
         u.created_at, IFNULL(u.updated_at, u.created_at) AS updated_at
    FROM units u
   WHERE u.id = p_id;
END
