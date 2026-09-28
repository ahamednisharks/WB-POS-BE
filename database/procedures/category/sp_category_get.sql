-- sp_category_get
-- Purpose : One category.
-- Params  : p_id
-- Results : (1) category row
-- Errors  : 45404 not found
CREATE PROCEDURE sp_category_get(IN p_id INT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM categories WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Category not found';
  END IF;

  SELECT c.id, c.category_name AS name, c.image_url AS image, c.display_order,
         IF(c.status = 1, 'ACTIVE', 'INACTIVE') AS status,
         (SELECT COUNT(*) FROM items i WHERE i.category_id = c.id AND i.is_deleted = 0) AS item_count,
         c.created_at, IFNULL(c.updated_at, c.created_at) AS updated_at
    FROM categories c
   WHERE c.id = p_id;
END
