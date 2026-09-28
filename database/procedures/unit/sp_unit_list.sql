-- sp_unit_list
-- Purpose : Paged unit list.
-- Params  : p_search (name / short code), p_status (1 / 0 / NULL = all), p_sort_by (name|shortCode|allowDecimal|status|createdAt),
--           p_sort_dir (asc|desc), p_page (1-based), p_limit (max 1000)
-- Results : (1) rows, (2) total
-- Errors  : none
CREATE PROCEDURE sp_unit_list(
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

  SELECT u.id, u.unit_name AS name, u.short_code, u.allow_decimal,
         IF(u.status = 1, 'ACTIVE', 'INACTIVE') AS status,
         (SELECT COUNT(*) FROM items i WHERE i.unit_id = u.id AND i.is_deleted = 0) AS item_count,
         u.created_at, IFNULL(u.updated_at, u.created_at) AS updated_at
    FROM units u
   WHERE u.is_deleted = 0
     AND (p_status IS NULL OR u.status = p_status)
     AND (IFNULL(p_search, '') = '' OR u.unit_name LIKE CONCAT('%', p_search, '%') OR u.short_code LIKE CONCAT('%', p_search, '%'))
   ORDER BY
     CASE WHEN p_sort_by = 'name'         AND p_sort_dir = 'asc'  THEN u.unit_name END ASC,
     CASE WHEN p_sort_by = 'name'         AND p_sort_dir = 'desc' THEN u.unit_name END DESC,
     CASE WHEN p_sort_by = 'shortCode'    AND p_sort_dir = 'asc'  THEN u.short_code END ASC,
     CASE WHEN p_sort_by = 'shortCode'    AND p_sort_dir = 'desc' THEN u.short_code END DESC,
     CASE WHEN p_sort_by = 'allowDecimal' AND p_sort_dir = 'asc'  THEN u.allow_decimal END ASC,
     CASE WHEN p_sort_by = 'allowDecimal' AND p_sort_dir = 'desc' THEN u.allow_decimal END DESC,
     CASE WHEN p_sort_by = 'status'       AND p_sort_dir = 'asc'  THEN u.status END ASC,
     CASE WHEN p_sort_by = 'status'       AND p_sort_dir = 'desc' THEN u.status END DESC,
     CASE WHEN p_sort_by = 'createdAt'    AND p_sort_dir = 'asc'  THEN u.id END ASC,
     u.id DESC
   LIMIT v_limit OFFSET v_offset;

  SELECT COUNT(*) AS total
    FROM units u
   WHERE u.is_deleted = 0
     AND (p_status IS NULL OR u.status = p_status)
     AND (IFNULL(p_search, '') = '' OR u.unit_name LIKE CONCAT('%', p_search, '%') OR u.short_code LIKE CONCAT('%', p_search, '%'));
END
