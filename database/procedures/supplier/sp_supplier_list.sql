-- sp_supplier_list
-- Purpose : Paged supplier list.
-- Params  : p_search (name, code, mobile, GSTIN, contact), p_status (1/0/NULL), p_state (name or code),
--           p_sort_by (code|name|mobile|gstin|currentBalance|status|createdAt), p_sort_dir, p_page, p_limit
-- Results : (1) rows, (2) total
-- Errors  : none
CREATE PROCEDURE sp_supplier_list(
  IN p_search   VARCHAR(100),
  IN p_status   TINYINT,
  IN p_state    VARCHAR(60),
  IN p_sort_by  VARCHAR(30),
  IN p_sort_dir VARCHAR(4),
  IN p_page     INT,
  IN p_limit    INT
)
BEGIN
  DECLARE v_limit  INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 10), 1), 1000);
  DECLARE v_offset INT DEFAULT (GREATEST(IFNULL(p_page, 1), 1) - 1) * v_limit;
  DECLARE v_shop_state CHAR(2);

  SELECT MAX(state_code) INTO v_shop_state FROM shop_settings WHERE id = 1;

  SELECT s.id, s.supplier_code AS code, s.supplier_name AS name, IFNULL(s.contact_person, '') AS contact_person,
         s.mobile, IFNULL(s.email, '') AS email, IFNULL(s.address, '') AS address,
         st.state_name AS state, s.state_code, IFNULL(s.gstin, '') AS gstin,
         s.opening_balance, s.payment_terms_days, s.current_balance,
         IF(s.state_code <> v_shop_state, 1, 0) AS is_inter_state,
         IF(s.status = 1, 'ACTIVE', 'INACTIVE') AS status,
         s.created_at, IFNULL(s.updated_at, s.created_at) AS updated_at
    FROM suppliers s
    JOIN states st ON st.state_code = s.state_code
   WHERE s.is_deleted = 0
     AND (p_status IS NULL OR s.status = p_status)
     AND (IFNULL(p_state, '') = '' OR s.state_code = p_state OR st.state_name = p_state)
     AND (IFNULL(p_search, '') = ''
          OR s.supplier_name LIKE CONCAT('%', p_search, '%')
          OR s.supplier_code LIKE CONCAT('%', p_search, '%')
          OR s.mobile LIKE CONCAT('%', p_search, '%')
          OR s.gstin LIKE CONCAT('%', p_search, '%')
          OR s.contact_person LIKE CONCAT('%', p_search, '%'))
   ORDER BY
     CASE WHEN p_sort_by = 'code'           AND p_sort_dir = 'asc'  THEN s.supplier_code END ASC,
     CASE WHEN p_sort_by = 'code'           AND p_sort_dir = 'desc' THEN s.supplier_code END DESC,
     CASE WHEN p_sort_by = 'name'           AND p_sort_dir = 'asc'  THEN s.supplier_name END ASC,
     CASE WHEN p_sort_by = 'name'           AND p_sort_dir = 'desc' THEN s.supplier_name END DESC,
     CASE WHEN p_sort_by = 'mobile'         AND p_sort_dir = 'asc'  THEN s.mobile END ASC,
     CASE WHEN p_sort_by = 'mobile'         AND p_sort_dir = 'desc' THEN s.mobile END DESC,
     CASE WHEN p_sort_by = 'gstin'          AND p_sort_dir = 'asc'  THEN s.gstin END ASC,
     CASE WHEN p_sort_by = 'gstin'          AND p_sort_dir = 'desc' THEN s.gstin END DESC,
     CASE WHEN p_sort_by = 'currentBalance' AND p_sort_dir = 'asc'  THEN s.current_balance END ASC,
     CASE WHEN p_sort_by = 'currentBalance' AND p_sort_dir = 'desc' THEN s.current_balance END DESC,
     CASE WHEN p_sort_by = 'status'         AND p_sort_dir = 'asc'  THEN s.status END ASC,
     CASE WHEN p_sort_by = 'status'         AND p_sort_dir = 'desc' THEN s.status END DESC,
     CASE WHEN p_sort_by = 'createdAt'      AND p_sort_dir = 'asc'  THEN s.id END ASC,
     s.id DESC
   LIMIT v_limit OFFSET v_offset;

  SELECT COUNT(*) AS total
    FROM suppliers s
    JOIN states st ON st.state_code = s.state_code
   WHERE s.is_deleted = 0
     AND (p_status IS NULL OR s.status = p_status)
     AND (IFNULL(p_state, '') = '' OR s.state_code = p_state OR st.state_name = p_state)
     AND (IFNULL(p_search, '') = ''
          OR s.supplier_name LIKE CONCAT('%', p_search, '%')
          OR s.supplier_code LIKE CONCAT('%', p_search, '%')
          OR s.mobile LIKE CONCAT('%', p_search, '%')
          OR s.gstin LIKE CONCAT('%', p_search, '%')
          OR s.contact_person LIKE CONCAT('%', p_search, '%'));
END
