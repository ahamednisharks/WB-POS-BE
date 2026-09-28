-- sp_pe_list
-- Purpose : Paged purchase entries with footer totals for the same filter.
-- Params  : p_search (PE no, invoice no, supplier, PO no), p_supplier_id, p_payment_status (UNPAID|PARTLY_PAID|PARTIAL|PAID|NULL),
--           p_from DATE, p_to DATE,
--           p_sort_by (peNo|peDate|supplierName|invoiceNo|poNo|grandTotal|paidAmount|balance|paymentStatus|dueDate|createdAt),
--           p_sort_dir, p_page, p_limit
-- Results : (1) rows, (2) total, (3) totals (grand_total, paid_amount, balance)
-- Errors  : none
CREATE PROCEDURE sp_pe_list(
  IN p_search         VARCHAR(100),
  IN p_supplier_id    INT,
  IN p_payment_status VARCHAR(12),
  IN p_from           DATE,
  IN p_to             DATE,
  IN p_sort_by        VARCHAR(30),
  IN p_sort_dir       VARCHAR(4),
  IN p_page           INT,
  IN p_limit          INT
)
BEGIN
  DECLARE v_limit      INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 10), 1), 1000);
  DECLARE v_offset     INT DEFAULT (GREATEST(IFNULL(p_page, 1), 1) - 1) * v_limit;
  DECLARE v_status     VARCHAR(12) DEFAULT IF(p_payment_status = 'PARTLY_PAID', 'PARTIAL', NULLIF(p_payment_status, ''));
  DECLARE v_shop_state CHAR(2);

  SELECT MAX(state_code) INTO v_shop_state FROM shop_settings WHERE id = 1;

  SELECT pe.id, pe.pe_no, pe.pe_date, pe.supplier_id, s.supplier_name, st.state_name AS supplier_state,
         IF(s.state_code <> v_shop_state, 1, 0) AS is_inter_state, pe.po_id, po.po_no,
         pe.supplier_invoice_no AS invoice_no, pe.invoice_date, pe.invoice_file_url, pe.invoice_file_name,
         (SELECT COUNT(*) FROM purchase_entry_items pi WHERE pi.pe_id = pe.id) AS item_count,
         pe.sub_total, pe.cgst, pe.sgst, pe.igst, pe.cgst + pe.sgst + pe.igst AS total_gst, pe.discount,
         pe.other_charges, pe.round_off, pe.grand_total, pe.paid_amount, pe.balance, pe.due_date,
         CASE pe.payment_status WHEN 'PARTIAL' THEN 'PARTLY_PAID' ELSE pe.payment_status END AS payment_status,
         IF(DATE(pe.created_at) = CURDATE(), 1, 0) AS is_editable,
         pe.created_at, IFNULL(pe.updated_at, pe.created_at) AS updated_at
    FROM purchase_entries pe
    JOIN suppliers s ON s.id = pe.supplier_id
    JOIN states st   ON st.state_code = s.state_code
    LEFT JOIN purchase_orders po ON po.id = pe.po_id
   WHERE pe.is_deleted = 0
     AND (p_supplier_id IS NULL OR pe.supplier_id = p_supplier_id)
     AND (v_status IS NULL OR pe.payment_status = v_status)
     AND (p_from IS NULL OR pe.pe_date >= p_from)
     AND (p_to IS NULL OR pe.pe_date <= p_to)
     AND (IFNULL(p_search, '') = ''
          OR pe.pe_no LIKE CONCAT('%', p_search, '%')
          OR pe.supplier_invoice_no LIKE CONCAT('%', p_search, '%')
          OR s.supplier_name LIKE CONCAT('%', p_search, '%')
          OR po.po_no LIKE CONCAT('%', p_search, '%'))
   ORDER BY
     CASE WHEN p_sort_by = 'peNo'          AND p_sort_dir = 'asc'  THEN pe.pe_no END ASC,
     CASE WHEN p_sort_by = 'peNo'          AND p_sort_dir = 'desc' THEN pe.pe_no END DESC,
     CASE WHEN p_sort_by = 'peDate'        AND p_sort_dir = 'asc'  THEN pe.pe_date END ASC,
     CASE WHEN p_sort_by = 'peDate'        AND p_sort_dir = 'desc' THEN pe.pe_date END DESC,
     CASE WHEN p_sort_by = 'supplierName'  AND p_sort_dir = 'asc'  THEN s.supplier_name END ASC,
     CASE WHEN p_sort_by = 'supplierName'  AND p_sort_dir = 'desc' THEN s.supplier_name END DESC,
     CASE WHEN p_sort_by = 'invoiceNo'     AND p_sort_dir = 'asc'  THEN pe.supplier_invoice_no END ASC,
     CASE WHEN p_sort_by = 'invoiceNo'     AND p_sort_dir = 'desc' THEN pe.supplier_invoice_no END DESC,
     CASE WHEN p_sort_by = 'poNo'          AND p_sort_dir = 'asc'  THEN po.po_no END ASC,
     CASE WHEN p_sort_by = 'poNo'          AND p_sort_dir = 'desc' THEN po.po_no END DESC,
     CASE WHEN p_sort_by = 'grandTotal'    AND p_sort_dir = 'asc'  THEN pe.grand_total END ASC,
     CASE WHEN p_sort_by = 'grandTotal'    AND p_sort_dir = 'desc' THEN pe.grand_total END DESC,
     CASE WHEN p_sort_by = 'paidAmount'    AND p_sort_dir = 'asc'  THEN pe.paid_amount END ASC,
     CASE WHEN p_sort_by = 'paidAmount'    AND p_sort_dir = 'desc' THEN pe.paid_amount END DESC,
     CASE WHEN p_sort_by = 'balance'       AND p_sort_dir = 'asc'  THEN pe.balance END ASC,
     CASE WHEN p_sort_by = 'balance'       AND p_sort_dir = 'desc' THEN pe.balance END DESC,
     CASE WHEN p_sort_by = 'paymentStatus' AND p_sort_dir = 'asc'  THEN pe.payment_status END ASC,
     CASE WHEN p_sort_by = 'paymentStatus' AND p_sort_dir = 'desc' THEN pe.payment_status END DESC,
     CASE WHEN p_sort_by = 'dueDate'       AND p_sort_dir = 'asc'  THEN pe.due_date END ASC,
     CASE WHEN p_sort_by = 'dueDate'       AND p_sort_dir = 'desc' THEN pe.due_date END DESC,
     CASE WHEN p_sort_by = 'createdAt'     AND p_sort_dir = 'asc'  THEN pe.id END ASC,
     pe.id DESC
   LIMIT v_limit OFFSET v_offset;

  SELECT COUNT(*) AS total
    FROM purchase_entries pe
    JOIN suppliers s ON s.id = pe.supplier_id
    LEFT JOIN purchase_orders po ON po.id = pe.po_id
   WHERE pe.is_deleted = 0
     AND (p_supplier_id IS NULL OR pe.supplier_id = p_supplier_id)
     AND (v_status IS NULL OR pe.payment_status = v_status)
     AND (p_from IS NULL OR pe.pe_date >= p_from)
     AND (p_to IS NULL OR pe.pe_date <= p_to)
     AND (IFNULL(p_search, '') = ''
          OR pe.pe_no LIKE CONCAT('%', p_search, '%')
          OR pe.supplier_invoice_no LIKE CONCAT('%', p_search, '%')
          OR s.supplier_name LIKE CONCAT('%', p_search, '%')
          OR po.po_no LIKE CONCAT('%', p_search, '%'));

  SELECT IFNULL(SUM(pe.grand_total), 0) AS grand_total, IFNULL(SUM(pe.paid_amount), 0) AS paid_amount,
         IFNULL(SUM(pe.balance), 0) AS balance
    FROM purchase_entries pe
    JOIN suppliers s ON s.id = pe.supplier_id
    LEFT JOIN purchase_orders po ON po.id = pe.po_id
   WHERE pe.is_deleted = 0
     AND (p_supplier_id IS NULL OR pe.supplier_id = p_supplier_id)
     AND (v_status IS NULL OR pe.payment_status = v_status)
     AND (p_from IS NULL OR pe.pe_date >= p_from)
     AND (p_to IS NULL OR pe.pe_date <= p_to)
     AND (IFNULL(p_search, '') = ''
          OR pe.pe_no LIKE CONCAT('%', p_search, '%')
          OR pe.supplier_invoice_no LIKE CONCAT('%', p_search, '%')
          OR s.supplier_name LIKE CONCAT('%', p_search, '%')
          OR po.po_no LIKE CONCAT('%', p_search, '%'));
END
