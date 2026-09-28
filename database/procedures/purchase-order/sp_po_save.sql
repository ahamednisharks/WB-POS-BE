-- sp_po_save
-- Purpose : Create (p_id = 0) or edit a DRAFT purchase order. No stock movement.
--           Items must be RAW or BOTH. Rates exclude GST; IGST when the supplier is in another state, else CGST + SGST.
--           Totals: sub total + GST + other charges, rounded to the rupee.
-- Params  : p_id, p_po_date, p_supplier_id, p_expected_date, p_notes, p_other_charges, p_action (DRAFT|SEND),
--           p_items JSON [{ "itemId": 7, "qty": 25, "rate": 42.5, "gstPercent": 5 }], p_user_id
-- Results : (1) id, message
-- Errors  : 45000 validation / not a draft, 45404 not found
CREATE PROCEDURE sp_po_save(
  IN p_id            INT,
  IN p_po_date       DATE,
  IN p_supplier_id   INT,
  IN p_expected_date DATE,
  IN p_notes         VARCHAR(500),
  IN p_other_charges DECIMAL(12,2),
  IN p_action        VARCHAR(5),
  IN p_items         JSON,
  IN p_user_id       INT
)
BEGIN
  DECLARE v_id         INT DEFAULT IFNULL(p_id, 0);
  DECLARE v_status     VARCHAR(10) DEFAULT NULL;
  DECLARE v_inter      INT DEFAULT 0;
  DECLARE v_count      INT DEFAULT 0;
  DECLARE v_distinct   INT DEFAULT 0;
  DECLARE v_invalid    INT DEFAULT 0;
  DECLARE v_bad_qty    INT DEFAULT 0;
  DECLARE v_bad_gst    INT DEFAULT 0;
  DECLARE v_sub        DECIMAL(12,2) DEFAULT 0;
  DECLARE v_gst        DECIMAL(12,2) DEFAULT 0;
  DECLARE v_cgst       DECIMAL(12,2) DEFAULT 0;
  DECLARE v_sgst       DECIMAL(12,2) DEFAULT 0;
  DECLARE v_igst       DECIMAL(12,2) DEFAULT 0;
  DECLARE v_other      DECIMAL(12,2) DEFAULT ROUND(GREATEST(IFNULL(p_other_charges, 0), 0), 2);
  DECLARE v_exact      DECIMAL(12,2);
  DECLARE v_grand      DECIMAL(12,2);
  DECLARE v_po_no      VARCHAR(20);
  DECLARE v_bad_name   VARCHAR(60) DEFAULT NULL;
  DECLARE v_msg        VARCHAR(128);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF IFNULL(p_action, '') NOT IN ('DRAFT', 'SEND') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'status::Action must be DRAFT or SEND';
  END IF;
  IF p_po_date IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'poDate::PO date is required';
  END IF;
  IF p_expected_date IS NOT NULL AND p_expected_date < p_po_date THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'expectedDate::Expected delivery date cannot be before the PO date';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM suppliers WHERE id = p_supplier_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'supplierId::Supplier not found';
  END IF;

  IF v_id > 0 THEN
    SELECT po_status INTO v_status FROM purchase_orders WHERE id = v_id AND is_deleted = 0;
    IF v_status IS NULL THEN
      SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Purchase order not found';
    END IF;
    IF v_status <> 'DRAFT' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only draft purchase orders can be edited';
    END IF;
  END IF;

  SELECT IF(s.state_code <> (SELECT state_code FROM shop_settings WHERE id = 1), 1, 0) INTO v_inter
    FROM suppliers s WHERE s.id = p_supplier_id;

  DROP TEMPORARY TABLE IF EXISTS tmp_po_items;
  CREATE TEMPORARY TABLE tmp_po_items (
    line_no    INT NOT NULL PRIMARY KEY,
    item_id    INT NULL,
    item_name  VARCHAR(60) NULL,
    qty        DECIMAL(12,3) NULL,
    rate       DECIMAL(12,2) NULL,
    gst_pct    DECIMAL(5,2) NULL,
    amount     DECIMAL(12,2) NOT NULL DEFAULT 0,
    gst_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    valid      TINYINT NOT NULL DEFAULT 0
  ) ENGINE=MEMORY;

  INSERT INTO tmp_po_items (line_no, item_id, qty, rate, gst_pct)
  SELECT jt.line_no, jt.item_id, ROUND(jt.qty, 3), ROUND(jt.rate, 2), jt.gst_pct
    FROM JSON_TABLE(IFNULL(p_items, JSON_ARRAY()), '$[*]' COLUMNS (
           line_no FOR ORDINALITY,
           item_id INT           PATH '$.itemId'     NULL ON EMPTY,
           qty     DECIMAL(12,3) PATH '$.qty'        NULL ON EMPTY,
           rate    DECIMAL(12,2) PATH '$.rate'       NULL ON EMPTY,
           gst_pct DECIMAL(5,2)  PATH '$.gstPercent' NULL ON EMPTY
         )) AS jt;

  UPDATE tmp_po_items t JOIN items i ON i.id = t.item_id
     SET t.item_name = i.item_name, t.gst_pct = IFNULL(t.gst_pct, i.gst_pct),
         t.valid = IF(i.is_deleted = 0 AND i.item_type IN ('RAW', 'BOTH'), 1, 0);

  SELECT COUNT(*), COUNT(DISTINCT item_id), IFNULL(SUM(valid = 0), 0),
         IFNULL(SUM(IFNULL(qty, 0) <= 0 OR IFNULL(rate, 0) <= 0), 0),
         IFNULL(SUM(IFNULL(gst_pct, -1) NOT IN (0, 5, 12, 18, 28)), 0)
    INTO v_count, v_distinct, v_invalid, v_bad_qty, v_bad_gst
    FROM tmp_po_items;

  IF v_count = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::Add at least one item';
  END IF;
  IF v_distinct <> v_count THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::Each item can be added only once';
  END IF;
  IF v_invalid > 0 THEN
    SELECT item_name INTO v_bad_name FROM tmp_po_items WHERE valid = 0 ORDER BY line_no LIMIT 1;
    SET v_msg = LEFT(CONCAT('items::', IFNULL(v_bad_name, 'An item'), ' is a sale-only item or no longer exists'), 128);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF v_bad_qty > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::Quantity and rate must be greater than 0';
  END IF;
  IF v_bad_gst > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::GST % must be one of 0, 5, 12, 18, 28';
  END IF;

  UPDATE tmp_po_items SET amount = ROUND(qty * rate, 2);
  UPDATE tmp_po_items SET gst_amount = ROUND(amount * gst_pct / 100, 2);
  SELECT IFNULL(SUM(amount), 0), IFNULL(SUM(gst_amount), 0) INTO v_sub, v_gst FROM tmp_po_items;

  IF v_inter = 1 THEN
    SET v_igst = v_gst;
  ELSE
    SET v_cgst = ROUND(v_gst / 2, 2);
    SET v_sgst = v_gst - v_cgst;
  END IF;
  SET v_exact = v_sub + v_gst + v_other;
  SET v_grand = GREATEST(ROUND(v_exact, 0), 0);

  START TRANSACTION;

  IF v_id = 0 THEN
    CALL sp_util_next_number('PO', v_po_no);
    INSERT INTO purchase_orders (po_no, po_date, supplier_id, expected_date, notes, sub_total, cgst, sgst, igst,
                                 other_charges, round_off, grand_total, po_status, created_by)
    VALUES (v_po_no, p_po_date, p_supplier_id, p_expected_date, NULLIF(TRIM(p_notes), ''), v_sub, v_cgst, v_sgst, v_igst,
            v_other, v_grand - v_exact, v_grand, IF(p_action = 'SEND', 'SENT', 'DRAFT'), p_user_id);
    SET v_id = LAST_INSERT_ID();
  ELSE
    UPDATE purchase_orders
       SET po_date = p_po_date, supplier_id = p_supplier_id, expected_date = p_expected_date,
           notes = NULLIF(TRIM(p_notes), ''), sub_total = v_sub, cgst = v_cgst, sgst = v_sgst, igst = v_igst,
           other_charges = v_other, round_off = v_grand - v_exact, grand_total = v_grand,
           po_status = IF(p_action = 'SEND', 'SENT', 'DRAFT'), updated_by = p_user_id, updated_at = NOW()
     WHERE id = v_id;
    DELETE FROM purchase_order_items WHERE po_id = v_id;
  END IF;

  INSERT INTO purchase_order_items (po_id, item_id, qty, received_qty, rate, gst_pct, amount, gst_amount)
  SELECT v_id, item_id, qty, 0, rate, gst_pct, amount, gst_amount FROM tmp_po_items ORDER BY line_no;

  COMMIT;
  DROP TEMPORARY TABLE IF EXISTS tmp_po_items;

  SELECT v_id AS id, IF(p_action = 'SEND', 'Purchase order saved and sent', 'Purchase order saved as draft') AS message;
END
