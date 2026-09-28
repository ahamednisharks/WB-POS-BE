-- sp_billing_catalog
-- Purpose : Everything the billing screen needs in one round trip.
-- Params  : none
-- Results : (1) active categories, (2) active SALE / BOTH items with unit and stock,
--           (3) combos active and valid today, (4) components of those combos
-- Errors  : none
CREATE PROCEDURE sp_billing_catalog()
BEGIN
  SELECT c.id, c.category_name AS name, c.image_url AS image, c.display_order
    FROM categories c
   WHERE c.is_deleted = 0 AND c.status = 1
   ORDER BY c.display_order, c.category_name;

  SELECT i.id, i.item_code AS code, i.item_name AS name, i.item_type AS type, i.category_id,
         i.unit_id, u.short_code AS unit_code, u.allow_decimal, i.selling_price, i.gst_pct AS gst_percent,
         i.price_includes_gst, IFNULL(i.barcode, '') AS barcode, i.current_stock, i.image_url AS image
    FROM items i
    JOIN units u ON u.id = i.unit_id
   WHERE i.is_deleted = 0 AND i.status = 1 AND i.item_type IN ('SALE', 'BOTH')
   ORDER BY i.item_name;

  SELECT c.id, c.combo_name AS name, c.combo_price, c.actual_price, c.actual_price - c.combo_price AS savings,
         c.gst_pct AS gst_percent, c.valid_from, c.valid_to, c.image_url AS image
    FROM combos c
   WHERE c.is_deleted = 0 AND c.status = 1
     AND (c.valid_from IS NULL OR c.valid_from <= CURDATE())
     AND (c.valid_to IS NULL OR c.valid_to >= CURDATE())
   ORDER BY c.combo_name;

  SELECT ci.combo_id, ci.item_id, i.item_name, ci.qty, ci.price
    FROM combo_items ci
    JOIN combos c ON c.id = ci.combo_id
    JOIN items i  ON i.id = ci.item_id
   WHERE c.is_deleted = 0 AND c.status = 1
     AND (c.valid_from IS NULL OR c.valid_from <= CURDATE())
     AND (c.valid_to IS NULL OR c.valid_to >= CURDATE())
   ORDER BY ci.combo_id, ci.id;
END
