-- sp_category_list
-- Purpose : Paged category list with item counts.
-- Params  : p_search, p_status (1/0/NULL), p_sort_by (name|displayOrder|itemCount|status|createdAt), p_sort_dir, p_page, p_limit
-- Results : (1) rows, (2) total
-- Errors  : none
CREATE PROCEDURE sp_category_list(
  IN p_search   VARCHAR(100),
  IN p_status   TINYINT,
  IN p_sort_by  VARCHAR(30),
  IN p_sort_dir VARCHAR(4),
  IN p_page     INT,
  IN p_limit    INT
)
BEGIN
  DECLARE v_limit  INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 10), 1), 1000);
  DECLARE v_offset INT DEFAULT (GREATEST(IFNULL(p_page, 1), 1) - 1) * v_limit;

  SELECT c.id, c.category_name AS name, c.image_url AS image, c.display_order,
         IF(c.status = 1, 'ACTIVE', 'INACTIVE') AS status,
         (SELECT COUNT(*) FROM items i WHERE i.category_id = c.id AND i.is_deleted = 0) AS item_count,
         c.created_at, IFNULL(c.updated_at, c.created_at) AS updated_at
    FROM categories c
   WHERE c.is_deleted = 0
     AND (p_status IS NULL OR c.status = p_status)
     AND (IFNULL(p_search, '') = '' OR c.category_name LIKE CONCAT('%', p_search, '%'))
   ORDER BY
     CASE WHEN p_sort_by = 'name'         AND p_sort_dir = 'asc'  THEN c.category_name END ASC,
     CASE WHEN p_sort_by = 'name'         AND p_sort_dir = 'desc' THEN c.category_name END DESC,
     CASE WHEN p_sort_by = 'displayOrder' AND p_sort_dir = 'asc'  THEN c.display_order END ASC,
     CASE WHEN p_sort_by = 'displayOrder' AND p_sort_dir = 'desc' THEN c.display_order END DESC,
     CASE WHEN p_sort_by = 'itemCount'    AND p_sort_dir = 'asc'  THEN (SELECT COUNT(*) FROM items i WHERE i.category_id = c.id AND i.is_deleted = 0) END ASC,
     CASE WHEN p_sort_by = 'itemCount'    AND p_sort_dir = 'desc' THEN (SELECT COUNT(*) FROM items i WHERE i.category_id = c.id AND i.is_deleted = 0) END DESC,
     CASE WHEN p_sort_by = 'status'       AND p_sort_dir = 'asc'  THEN c.status END ASC,
     CASE WHEN p_sort_by = 'status'       AND p_sort_dir = 'desc' THEN c.status END DESC,
     CASE WHEN p_sort_by = 'createdAt'    AND p_sort_dir = 'asc'  THEN c.id END ASC,
     c.id DESC
   LIMIT v_limit OFFSET v_offset;

  SELECT COUNT(*) AS total
    FROM categories c
   WHERE c.is_deleted = 0
     AND (p_status IS NULL OR c.status = p_status)
     AND (IFNULL(p_search, '') = '' OR c.category_name LIKE CONCAT('%', p_search, '%'));
END
