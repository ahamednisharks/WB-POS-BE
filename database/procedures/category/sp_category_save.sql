-- sp_category_save
-- Purpose : Insert (p_id = 0) or update (p_id > 0) a category.
-- Params  : p_id, p_category_name, p_image_url, p_display_order, p_status, p_user_id
-- Results : (1) id, message
-- Errors  : 45000 name required, 45404 not found, 45409 duplicate name
CREATE PROCEDURE sp_category_save(
  IN p_id            INT,
  IN p_category_name VARCHAR(50),
  IN p_image_url     VARCHAR(255),
  IN p_display_order INT,
  IN p_status        TINYINT,
  IN p_user_id       INT
)
BEGIN
  DECLARE v_id INT DEFAULT IFNULL(p_id, 0);

  IF TRIM(IFNULL(p_category_name, '')) = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'name::Category name is required';
  END IF;

  IF EXISTS (SELECT 1 FROM categories
             WHERE category_name = TRIM(p_category_name) AND id <> v_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45409' SET MESSAGE_TEXT = 'name::Category name already exists';
  END IF;

  IF v_id = 0 THEN
    INSERT INTO categories (category_name, image_url, display_order, status, created_by)
    VALUES (TRIM(p_category_name), p_image_url, GREATEST(IFNULL(p_display_order, 0), 0), IFNULL(p_status, 1), p_user_id);
    SET v_id = LAST_INSERT_ID();
  ELSE
    IF NOT EXISTS (SELECT 1 FROM categories WHERE id = v_id AND is_deleted = 0) THEN
      SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Category not found';
    END IF;
    UPDATE categories
       SET category_name = TRIM(p_category_name), image_url = p_image_url,
           display_order = GREATEST(IFNULL(p_display_order, 0), 0), status = IFNULL(p_status, 1),
           updated_by = p_user_id, updated_at = NOW()
     WHERE id = v_id;
  END IF;

  SELECT v_id AS id, 'Category saved successfully' AS message;
END
