-- sp_category_dropdown
-- Purpose : Active categories for select boxes, in display order.
-- Params  : none
-- Results : (1) id, name, image, display_order
-- Errors  : none
CREATE PROCEDURE sp_category_dropdown()
BEGIN
  SELECT id, category_name AS name, image_url AS image, display_order
    FROM categories
   WHERE is_deleted = 0 AND status = 1
   ORDER BY display_order, category_name;
END
