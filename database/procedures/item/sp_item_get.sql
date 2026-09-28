-- sp_item_get
-- Purpose : One item with category / unit names.
-- Params  : p_id
-- Results : (1) item row
-- Errors  : 45404 not found
CREATE PROCEDURE sp_item_get(IN p_id INT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM items WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Item not found';
  END IF;

  SELECT i.id, i.item_code AS code, i.item_name AS name, i.item_type AS type,
         i.category_id, c.category_name, i.unit_id, u.unit_name, u.short_code AS unit_code, u.allow_decimal,
         i.selling_price, i.purchase_price, i.gst_pct AS gst_percent, i.price_includes_gst,
         IFNULL(i.hsn_code, '') AS hsn_code, IFNULL(i.barcode, '') AS barcode,
         i.current_stock, i.min_stock, i.image_url AS image,
         IF(i.status = 1, 'ACTIVE', 'INACTIVE') AS status,
         i.created_at, IFNULL(i.updated_at, i.created_at) AS updated_at
    FROM items i
    JOIN categories c ON c.id = i.category_id
    JOIN units u      ON u.id = i.unit_id
   WHERE i.id = p_id;
END
