-- sp_item_list
-- Purpose : Paged item list with category / unit names.
-- Params  : p_search (name, code, barcode, category), p_status (1/0/NULL), p_category_id, p_item_type (SALE|RAW|BOTH),
--           p_barcode (exact), p_saleable (1 = SALE/BOTH), p_purchasable (1 = RAW/BOTH), p_low_stock (1 = stock <= min, stock-tracked only),
--           p_sort_by (code|name|type|categoryName|sellingPrice|gstPercent|currentStock|status|createdAt), p_sort_dir, p_page, p_limit
-- Results : (1) rows, (2) total
-- Errors  : none
CREATE PROCEDURE sp_item_list(
  IN p_search      VARCHAR(100),
  IN p_status      TINYINT,
  IN p_category_id INT,
  IN p_item_type   VARCHAR(4),
  IN p_barcode     VARCHAR(40),
  IN p_saleable    TINYINT,
  IN p_purchasable TINYINT,
  IN p_low_stock   TINYINT,
  IN p_sort_by     VARCHAR(30),
  IN p_sort_dir    VARCHAR(4),
  IN p_page        INT,
  IN p_limit       INT
)
BEGIN
  DECLARE v_limit  INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 10), 1), 1000);
  DECLARE v_offset INT DEFAULT (GREATEST(IFNULL(p_page, 1), 1) - 1) * v_limit;

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
   WHERE i.is_deleted = 0
     AND (p_status IS NULL OR i.status = p_status)
     AND (p_category_id IS NULL OR i.category_id = p_category_id)
     AND (IFNULL(p_item_type, '') = '' OR i.item_type = p_item_type)
     AND (IFNULL(p_barcode, '') = '' OR i.barcode = p_barcode)
     AND (IFNULL(p_saleable, 0) = 0 OR i.item_type IN ('SALE', 'BOTH'))
     AND (IFNULL(p_purchasable, 0) = 0 OR i.item_type IN ('RAW', 'BOTH'))
     AND (IFNULL(p_low_stock, 0) = 0 OR (i.item_type <> 'SALE' AND i.current_stock <= i.min_stock))
     AND (IFNULL(p_search, '') = ''
          OR i.item_name LIKE CONCAT('%', p_search, '%')
          OR i.item_code LIKE CONCAT('%', p_search, '%')
          OR i.barcode = p_search
          OR c.category_name LIKE CONCAT('%', p_search, '%'))
   ORDER BY
     CASE WHEN p_sort_by = 'code'         AND p_sort_dir = 'asc'  THEN i.item_code END ASC,
     CASE WHEN p_sort_by = 'code'         AND p_sort_dir = 'desc' THEN i.item_code END DESC,
     CASE WHEN p_sort_by = 'name'         AND p_sort_dir = 'asc'  THEN i.item_name END ASC,
     CASE WHEN p_sort_by = 'name'         AND p_sort_dir = 'desc' THEN i.item_name END DESC,
     CASE WHEN p_sort_by = 'type'         AND p_sort_dir = 'asc'  THEN i.item_type END ASC,
     CASE WHEN p_sort_by = 'type'         AND p_sort_dir = 'desc' THEN i.item_type END DESC,
     CASE WHEN p_sort_by = 'categoryName' AND p_sort_dir = 'asc'  THEN c.category_name END ASC,
     CASE WHEN p_sort_by = 'categoryName' AND p_sort_dir = 'desc' THEN c.category_name END DESC,
     CASE WHEN p_sort_by = 'sellingPrice' AND p_sort_dir = 'asc'  THEN i.selling_price END ASC,
     CASE WHEN p_sort_by = 'sellingPrice' AND p_sort_dir = 'desc' THEN i.selling_price END DESC,
     CASE WHEN p_sort_by = 'gstPercent'   AND p_sort_dir = 'asc'  THEN i.gst_pct END ASC,
     CASE WHEN p_sort_by = 'gstPercent'   AND p_sort_dir = 'desc' THEN i.gst_pct END DESC,
     CASE WHEN p_sort_by = 'currentStock' AND p_sort_dir = 'asc'  THEN i.current_stock END ASC,
     CASE WHEN p_sort_by = 'currentStock' AND p_sort_dir = 'desc' THEN i.current_stock END DESC,
     CASE WHEN p_sort_by = 'status'       AND p_sort_dir = 'asc'  THEN i.status END ASC,
     CASE WHEN p_sort_by = 'status'       AND p_sort_dir = 'desc' THEN i.status END DESC,
     CASE WHEN p_sort_by = 'createdAt'    AND p_sort_dir = 'asc'  THEN i.id END ASC,
     i.id DESC
   LIMIT v_limit OFFSET v_offset;

  SELECT COUNT(*) AS total
    FROM items i
    JOIN categories c ON c.id = i.category_id
   WHERE i.is_deleted = 0
     AND (p_status IS NULL OR i.status = p_status)
     AND (p_category_id IS NULL OR i.category_id = p_category_id)
     AND (IFNULL(p_item_type, '') = '' OR i.item_type = p_item_type)
     AND (IFNULL(p_barcode, '') = '' OR i.barcode = p_barcode)
     AND (IFNULL(p_saleable, 0) = 0 OR i.item_type IN ('SALE', 'BOTH'))
     AND (IFNULL(p_purchasable, 0) = 0 OR i.item_type IN ('RAW', 'BOTH'))
     AND (IFNULL(p_low_stock, 0) = 0 OR (i.item_type <> 'SALE' AND i.current_stock <= i.min_stock))
     AND (IFNULL(p_search, '') = ''
          OR i.item_name LIKE CONCAT('%', p_search, '%')
          OR i.item_code LIKE CONCAT('%', p_search, '%')
          OR i.barcode = p_search
          OR c.category_name LIKE CONCAT('%', p_search, '%'));
END
