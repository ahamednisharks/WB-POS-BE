-- sp_item_dropdown
-- Purpose : Active items for select boxes. p_type 'SALE' -> SALE + BOTH, 'RAW' -> RAW + BOTH, NULL -> all.
-- Params  : p_type
-- Results : (1) id, code, name, type, unit_code, allow_decimal, selling_price, purchase_price, gst_percent,
--               price_includes_gst, current_stock
-- Errors  : none
CREATE PROCEDURE sp_item_dropdown(IN p_type VARCHAR(4))
BEGIN
  SELECT i.id, i.item_code AS code, i.item_name AS name, i.item_type AS type,
         u.short_code AS unit_code, u.allow_decimal, i.selling_price, i.purchase_price,
         i.gst_pct AS gst_percent, i.price_includes_gst, i.current_stock
    FROM items i
    JOIN units u ON u.id = i.unit_id
   WHERE i.is_deleted = 0 AND i.status = 1
     AND (IFNULL(p_type, '') = ''
          OR (p_type = 'SALE' AND i.item_type IN ('SALE', 'BOTH'))
          OR (p_type = 'RAW'  AND i.item_type IN ('RAW', 'BOTH'))
          OR (p_type = 'BOTH' AND i.item_type = 'BOTH'))
   ORDER BY i.item_name;
END
