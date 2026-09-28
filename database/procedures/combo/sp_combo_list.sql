-- sp_combo_list
-- Purpose : Paged combo list; each row carries its component items as JSON.
-- Params  : p_search (combo or component name), p_status (1/0/NULL), p_active_on DATE (active and valid on that day),
--           p_sort_by (name|actualPrice|comboPrice|validTo|status|createdAt), p_sort_dir, p_page, p_limit
-- Results : (1) rows, (2) total
-- Errors  : none
CREATE PROCEDURE sp_combo_list(
  IN p_search    VARCHAR(100),
  IN p_status    TINYINT,
  IN p_active_on DATE,
  IN p_sort_by   VARCHAR(30),
  IN p_sort_dir  VARCHAR(4),
  IN p_page      INT,
  IN p_limit     INT
)
BEGIN
  DECLARE v_limit  INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 10), 1), 1000);
  DECLARE v_offset INT DEFAULT (GREATEST(IFNULL(p_page, 1), 1) - 1) * v_limit;

  SELECT c.id, c.combo_name AS name,
         (SELECT JSON_ARRAYAGG(JSON_OBJECT('itemId', ci.item_id, 'itemName', i.item_name, 'qty', ci.qty, 'price', ci.price))
            FROM combo_items ci JOIN items i ON i.id = ci.item_id
           WHERE ci.combo_id = c.id) AS items,
         c.actual_price, c.combo_price, c.actual_price - c.combo_price AS savings,
         c.gst_pct AS gst_percent, c.valid_from, c.valid_to, c.image_url AS image,
         IF(c.status = 1, 'ACTIVE', 'INACTIVE') AS status,
         c.created_at, IFNULL(c.updated_at, c.created_at) AS updated_at
    FROM combos c
   WHERE c.is_deleted = 0
     AND (p_status IS NULL OR c.status = p_status)
     AND (p_active_on IS NULL OR (c.status = 1
          AND (c.valid_from IS NULL OR c.valid_from <= p_active_on)
          AND (c.valid_to IS NULL OR c.valid_to >= p_active_on)))
     AND (IFNULL(p_search, '') = ''
          OR c.combo_name LIKE CONCAT('%', p_search, '%')
          OR EXISTS (SELECT 1 FROM combo_items ci JOIN items i ON i.id = ci.item_id
                      WHERE ci.combo_id = c.id AND i.item_name LIKE CONCAT('%', p_search, '%')))
   ORDER BY
     CASE WHEN p_sort_by = 'name'        AND p_sort_dir = 'asc'  THEN c.combo_name END ASC,
     CASE WHEN p_sort_by = 'name'        AND p_sort_dir = 'desc' THEN c.combo_name END DESC,
     CASE WHEN p_sort_by = 'actualPrice' AND p_sort_dir = 'asc'  THEN c.actual_price END ASC,
     CASE WHEN p_sort_by = 'actualPrice' AND p_sort_dir = 'desc' THEN c.actual_price END DESC,
     CASE WHEN p_sort_by = 'comboPrice'  AND p_sort_dir = 'asc'  THEN c.combo_price END ASC,
     CASE WHEN p_sort_by = 'comboPrice'  AND p_sort_dir = 'desc' THEN c.combo_price END DESC,
     CASE WHEN p_sort_by = 'validTo'     AND p_sort_dir = 'asc'  THEN c.valid_to END ASC,
     CASE WHEN p_sort_by = 'validTo'     AND p_sort_dir = 'desc' THEN c.valid_to END DESC,
     CASE WHEN p_sort_by = 'status'      AND p_sort_dir = 'asc'  THEN c.status END ASC,
     CASE WHEN p_sort_by = 'status'      AND p_sort_dir = 'desc' THEN c.status END DESC,
     CASE WHEN p_sort_by = 'createdAt'   AND p_sort_dir = 'asc'  THEN c.id END ASC,
     c.id DESC
   LIMIT v_limit OFFSET v_offset;

  SELECT COUNT(*) AS total
    FROM combos c
   WHERE c.is_deleted = 0
     AND (p_status IS NULL OR c.status = p_status)
     AND (p_active_on IS NULL OR (c.status = 1
          AND (c.valid_from IS NULL OR c.valid_from <= p_active_on)
          AND (c.valid_to IS NULL OR c.valid_to >= p_active_on)))
     AND (IFNULL(p_search, '') = ''
          OR c.combo_name LIKE CONCAT('%', p_search, '%')
          OR EXISTS (SELECT 1 FROM combo_items ci JOIN items i ON i.id = ci.item_id
                      WHERE ci.combo_id = c.id AND i.item_name LIKE CONCAT('%', p_search, '%')));
END
