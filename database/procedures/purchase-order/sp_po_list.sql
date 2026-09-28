-- sp_po_list
-- Purpose : Paged purchase orders (items included as JSON so "Convert to PE" can pre-fill from the list).
-- Params  : p_search (PO no, supplier, item name), p_supplier_id, p_status (DRAFT|SENT|PARTIAL|RECEIVED|CANCELLED|OPEN = SENT+PARTIAL),
--           p_from DATE, p_to DATE, p_sort_by (poNo|poDate|supplierName|grandTotal|expectedDate|status|createdAt),
--           p_sort_dir, p_page, p_limit
-- Results : (1) rows, (2) total
-- Errors  : none
CREATE PROCEDURE sp_po_list(
  IN p_search      VARCHAR(100),
  IN p_supplier_id INT,
  IN p_status      VARCHAR(10),
  IN p_from        DATE,
  IN p_to          DATE,
  IN p_sort_by     VARCHAR(30),
  IN p_sort_dir    VARCHAR(4),
  IN p_page        INT,
  IN p_limit       INT
)
BEGIN
  DECLARE v_limit      INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 10), 1), 1000);
  DECLARE v_offset     INT DEFAULT (GREATEST(IFNULL(p_page, 1), 1) - 1) * v_limit;
  DECLARE v_shop_state CHAR(2);

  SELECT MAX(state_code) INTO v_shop_state FROM shop_settings WHERE id = 1;

  SELECT po.id, po.po_no, po.po_date, po.supplier_id, s.supplier_name, IFNULL(s.gstin, '') AS supplier_gstin,
         st.state_name AS supplier_state, s.mobile AS supplier_mobile, IF(s.state_code <> v_shop_state, 1, 0) AS is_inter_state,
         po.expected_date, IFNULL(po.notes, '') AS notes,
         (SELECT JSON_ARRAYAGG(JSON_OBJECT('poItemId', pi.id, 'itemId', pi.item_id, 'itemName', i.item_name,
                                           'unitCode', u.short_code, 'qty', pi.qty, 'receivedQty', pi.received_qty,
                                           'rate', pi.rate, 'gstPercent', pi.gst_pct, 'amount', pi.amount, 'gstAmount', pi.gst_amount))
            FROM purchase_order_items pi JOIN items i ON i.id = pi.item_id JOIN units u ON u.id = i.unit_id
           WHERE pi.po_id = po.id) AS items,
         po.sub_total, po.cgst, po.sgst, po.igst, po.cgst + po.sgst + po.igst AS total_gst, po.other_charges,
         po.round_off, po.grand_total, po.po_status AS status, po.cancel_reason,
         po.created_at, IFNULL(po.updated_at, po.created_at) AS updated_at
    FROM purchase_orders po
    JOIN suppliers s ON s.id = po.supplier_id
    JOIN states st   ON st.state_code = s.state_code
   WHERE po.is_deleted = 0
     AND (p_supplier_id IS NULL OR po.supplier_id = p_supplier_id)
     AND (IFNULL(p_status, '') = '' OR po.po_status = p_status OR (p_status = 'OPEN' AND po.po_status IN ('SENT', 'PARTIAL')))
     AND (p_from IS NULL OR po.po_date >= p_from)
     AND (p_to IS NULL OR po.po_date <= p_to)
     AND (IFNULL(p_search, '') = ''
          OR po.po_no LIKE CONCAT('%', p_search, '%')
          OR s.supplier_name LIKE CONCAT('%', p_search, '%')
          OR EXISTS (SELECT 1 FROM purchase_order_items pi JOIN items i ON i.id = pi.item_id
                      WHERE pi.po_id = po.id AND i.item_name LIKE CONCAT('%', p_search, '%')))
   ORDER BY
     CASE WHEN p_sort_by = 'poNo'         AND p_sort_dir = 'asc'  THEN po.po_no END ASC,
     CASE WHEN p_sort_by = 'poNo'         AND p_sort_dir = 'desc' THEN po.po_no END DESC,
     CASE WHEN p_sort_by = 'poDate'       AND p_sort_dir = 'asc'  THEN po.po_date END ASC,
     CASE WHEN p_sort_by = 'poDate'       AND p_sort_dir = 'desc' THEN po.po_date END DESC,
     CASE WHEN p_sort_by = 'supplierName' AND p_sort_dir = 'asc'  THEN s.supplier_name END ASC,
     CASE WHEN p_sort_by = 'supplierName' AND p_sort_dir = 'desc' THEN s.supplier_name END DESC,
     CASE WHEN p_sort_by = 'grandTotal'   AND p_sort_dir = 'asc'  THEN po.grand_total END ASC,
     CASE WHEN p_sort_by = 'grandTotal'   AND p_sort_dir = 'desc' THEN po.grand_total END DESC,
     CASE WHEN p_sort_by = 'expectedDate' AND p_sort_dir = 'asc'  THEN po.expected_date END ASC,
     CASE WHEN p_sort_by = 'expectedDate' AND p_sort_dir = 'desc' THEN po.expected_date END DESC,
     CASE WHEN p_sort_by = 'status'       AND p_sort_dir = 'asc'  THEN po.po_status END ASC,
     CASE WHEN p_sort_by = 'status'       AND p_sort_dir = 'desc' THEN po.po_status END DESC,
     CASE WHEN p_sort_by = 'createdAt'    AND p_sort_dir = 'asc'  THEN po.id END ASC,
     po.id DESC
   LIMIT v_limit OFFSET v_offset;

  SELECT COUNT(*) AS total
    FROM purchase_orders po
    JOIN suppliers s ON s.id = po.supplier_id
   WHERE po.is_deleted = 0
     AND (p_supplier_id IS NULL OR po.supplier_id = p_supplier_id)
     AND (IFNULL(p_status, '') = '' OR po.po_status = p_status OR (p_status = 'OPEN' AND po.po_status IN ('SENT', 'PARTIAL')))
     AND (p_from IS NULL OR po.po_date >= p_from)
     AND (p_to IS NULL OR po.po_date <= p_to)
     AND (IFNULL(p_search, '') = ''
          OR po.po_no LIKE CONCAT('%', p_search, '%')
          OR s.supplier_name LIKE CONCAT('%', p_search, '%')
          OR EXISTS (SELECT 1 FROM purchase_order_items pi JOIN items i ON i.id = pi.item_id
                      WHERE pi.po_id = po.id AND i.item_name LIKE CONCAT('%', p_search, '%')));
END
