-- sp_preorder_list
-- Purpose : Paged pre-order list, filtered by delivery date. Default order is soonest delivery first.
--           Visible to every user (not cashier-scoped like bills).
-- Params  : p_from DATE, p_to DATE (delivery date range), p_status (BOOKED|READY|DELIVERED|CANCELLED|OPEN|NULL,
--           OPEN = BOOKED + READY), p_search (order no, customer mobile / alt mobile / name),
--           p_sort_by (orderNo|orderDate|deliveryAt|customerName|grandTotal|balance|status|createdAt), p_sort_dir,
--           p_page, p_limit
-- Results : (1) rows (with items_summary), (2) total
-- Errors  : none
CREATE PROCEDURE sp_preorder_list(
  IN p_from     DATE,
  IN p_to       DATE,
  IN p_status   VARCHAR(10),
  IN p_search   VARCHAR(100),
  IN p_sort_by  VARCHAR(30),
  IN p_sort_dir VARCHAR(4),
  IN p_page     INT,
  IN p_limit    INT
)
BEGIN
  DECLARE v_limit  INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 10), 1), 1000);
  DECLARE v_offset INT DEFAULT (GREATEST(IFNULL(p_page, 1), 1) - 1) * v_limit;

  SELECT p.id, p.order_no, p.order_date, p.customer_mobile, p.customer_name, IFNULL(p.alt_mobile, '') AS alt_mobile,
         p.delivery_at, p.delivery_type, IFNULL(p.delivery_address, '') AS delivery_address, p.delivery_charge,
         p.item_count, p.sub_total, p.discount_amount, p.grand_total, p.paid_amount,
         p.grand_total - p.paid_amount AS balance, p.order_status AS status, p.bill_id, b.bill_no,
         (SELECT GROUP_CONCAT(CONCAT(li.item_name, ' x ', TRIM(TRAILING '.' FROM TRIM(TRAILING '0' FROM li.qty)))
                              ORDER BY li.line_no SEPARATOR ', ')
            FROM pre_order_items li WHERE li.pre_order_id = p.id) AS items_summary,
         COALESCE(e.full_name, IF(u.employee_id IS NULL AND u.role = 'ADMIN', 'Administrator', u.username)) AS booked_by_name,
         p.created_at, IFNULL(p.updated_at, p.created_at) AS updated_at
    FROM pre_orders p
    JOIN users u ON u.id = p.booked_by
    LEFT JOIN employees e ON e.id = u.employee_id
    LEFT JOIN bills b ON b.id = p.bill_id
   WHERE p.is_deleted = 0
     AND (p_from IS NULL OR p.delivery_at >= p_from)
     AND (p_to IS NULL OR p.delivery_at < p_to + INTERVAL 1 DAY)
     AND (IFNULL(p_status, '') = ''
          OR p.order_status = p_status
          OR (p_status = 'OPEN' AND p.order_status IN ('BOOKED', 'READY')))
     AND (IFNULL(p_search, '') = ''
          OR p.order_no LIKE CONCAT('%', p_search, '%')
          OR p.customer_mobile LIKE CONCAT('%', p_search, '%')
          OR p.alt_mobile LIKE CONCAT('%', p_search, '%')
          OR p.customer_name LIKE CONCAT('%', p_search, '%'))
   ORDER BY
     CASE WHEN p_sort_by = 'orderNo'      AND p_sort_dir = 'asc'  THEN p.order_no END ASC,
     CASE WHEN p_sort_by = 'orderNo'      AND p_sort_dir = 'desc' THEN p.order_no END DESC,
     CASE WHEN p_sort_by = 'orderDate'    AND p_sort_dir = 'asc'  THEN p.order_date END ASC,
     CASE WHEN p_sort_by = 'orderDate'    AND p_sort_dir = 'desc' THEN p.order_date END DESC,
     CASE WHEN p_sort_by = 'deliveryAt'   AND p_sort_dir = 'desc' THEN p.delivery_at END DESC,
     CASE WHEN p_sort_by = 'customerName' AND p_sort_dir = 'asc'  THEN p.customer_name END ASC,
     CASE WHEN p_sort_by = 'customerName' AND p_sort_dir = 'desc' THEN p.customer_name END DESC,
     CASE WHEN p_sort_by = 'grandTotal'   AND p_sort_dir = 'asc'  THEN p.grand_total END ASC,
     CASE WHEN p_sort_by = 'grandTotal'   AND p_sort_dir = 'desc' THEN p.grand_total END DESC,
     CASE WHEN p_sort_by = 'balance'      AND p_sort_dir = 'asc'  THEN p.grand_total - p.paid_amount END ASC,
     CASE WHEN p_sort_by = 'balance'      AND p_sort_dir = 'desc' THEN p.grand_total - p.paid_amount END DESC,
     CASE WHEN p_sort_by = 'status'       AND p_sort_dir = 'asc'  THEN p.order_status END ASC,
     CASE WHEN p_sort_by = 'status'       AND p_sort_dir = 'desc' THEN p.order_status END DESC,
     CASE WHEN p_sort_by = 'createdAt'    AND p_sort_dir = 'asc'  THEN p.id END ASC,
     CASE WHEN p_sort_by = 'createdAt'    AND p_sort_dir = 'desc' THEN p.id END DESC,
     p.delivery_at ASC, p.id ASC
   LIMIT v_limit OFFSET v_offset;

  SELECT COUNT(*) AS total
    FROM pre_orders p
   WHERE p.is_deleted = 0
     AND (p_from IS NULL OR p.delivery_at >= p_from)
     AND (p_to IS NULL OR p.delivery_at < p_to + INTERVAL 1 DAY)
     AND (IFNULL(p_status, '') = ''
          OR p.order_status = p_status
          OR (p_status = 'OPEN' AND p.order_status IN ('BOOKED', 'READY')))
     AND (IFNULL(p_search, '') = ''
          OR p.order_no LIKE CONCAT('%', p_search, '%')
          OR p.customer_mobile LIKE CONCAT('%', p_search, '%')
          OR p.alt_mobile LIKE CONCAT('%', p_search, '%')
          OR p.customer_name LIKE CONCAT('%', p_search, '%'));
END
