-- sp_pe_save
-- Purpose : Records a supplier invoice (goods received) in one transaction:
--           unique invoice no. per supplier; stock PURCHASE for received qty; items.purchase_price = latest rate;
--           received qty added to the PO lines and PO status set PARTIAL / RECEIVED; supplier balance increased by the
--           unpaid amount; paid_now stored as a supplier payment (+ CASH_OUT till transaction when paid in cash);
--           due_date = invoice_date + supplier payment terms. Rates exclude GST; IGST for other-state suppliers.
--           Edit (p_id > 0) is allowed on the day of entry only: old stock / PO / balance effects are reversed
--           (PE_EDIT) and the new ones applied. Payments are not changed by an edit.
-- Params  : p_id, p_pe_date, p_supplier_id, p_po_id, p_invoice_no, p_invoice_date, p_invoice_file_url, p_invoice_file_name,
--           p_discount, p_other_charges, p_paid_now, p_payment_mode (CASH|BANK|UPI|CHEQUE),
--           p_items JSON [{ "itemId": 7, "orderedQty": 25, "receivedQty": 25, "rate": 42.5, "gstPercent": 5, "expiryDate": "2026-12-31" }],
--           p_user_id
-- Results : (1) id, message
-- Errors  : 45000 validation, 45404 not found, 45409 duplicate invoice
CREATE PROCEDURE sp_pe_save(
  IN p_id                INT,
  IN p_pe_date           DATE,
  IN p_supplier_id       INT,
  IN p_po_id             INT,
  IN p_invoice_no        VARCHAR(40),
  IN p_invoice_date      DATE,
  IN p_invoice_file_url  VARCHAR(255),
  IN p_invoice_file_name VARCHAR(150),
  IN p_discount          DECIMAL(12,2),
  IN p_other_charges     DECIMAL(12,2),
  IN p_paid_now          DECIMAL(12,2),
  IN p_payment_mode      VARCHAR(10),
  IN p_items             JSON,
  IN p_user_id           INT
)
BEGIN
  DECLARE v_id          INT DEFAULT IFNULL(p_id, 0);
  DECLARE v_invoice     VARCHAR(40) DEFAULT TRIM(IFNULL(p_invoice_no, ''));
  DECLARE v_po          INT DEFAULT NULLIF(p_po_id, 0);
  DECLARE v_old_po      INT DEFAULT NULL;
  DECLARE v_old_supp    INT DEFAULT NULL;
  DECLARE v_old_grand   DECIMAL(12,2) DEFAULT 0;
  DECLARE v_old_paid    DECIMAL(12,2) DEFAULT 0;
  DECLARE v_created     DATE DEFAULT NULL;
  DECLARE v_po_supplier INT DEFAULT NULL;
  DECLARE v_po_status   VARCHAR(10) DEFAULT NULL;
  DECLARE v_inter       INT DEFAULT 0;
  DECLARE v_terms       INT DEFAULT 0;
  DECLARE v_supp_name   VARCHAR(80);
  DECLARE v_count       INT DEFAULT 0;
  DECLARE v_distinct    INT DEFAULT 0;
  DECLARE v_invalid     INT DEFAULT 0;
  DECLARE v_bad_qty     INT DEFAULT 0;
  DECLARE v_bad_gst     INT DEFAULT 0;
  DECLARE v_sub         DECIMAL(12,2) DEFAULT 0;
  DECLARE v_gst         DECIMAL(12,2) DEFAULT 0;
  DECLARE v_cgst        DECIMAL(12,2) DEFAULT 0;
  DECLARE v_sgst        DECIMAL(12,2) DEFAULT 0;
  DECLARE v_igst        DECIMAL(12,2) DEFAULT 0;
  DECLARE v_discount    DECIMAL(12,2) DEFAULT ROUND(GREATEST(IFNULL(p_discount, 0), 0), 2);
  DECLARE v_other       DECIMAL(12,2) DEFAULT ROUND(GREATEST(IFNULL(p_other_charges, 0), 0), 2);
  DECLARE v_paid_now    DECIMAL(12,2) DEFAULT ROUND(GREATEST(IFNULL(p_paid_now, 0), 0), 2);
  DECLARE v_paid        DECIMAL(12,2) DEFAULT 0;
  DECLARE v_exact       DECIMAL(12,2);
  DECLARE v_grand       DECIMAL(12,2);
  DECLARE v_pe_no       VARCHAR(20);
  DECLARE v_txn_no      VARCHAR(20);
  DECLARE v_bad_name    VARCHAR(60) DEFAULT NULL;
  DECLARE v_msg         VARCHAR(128);
  DECLARE v_i           INT DEFAULT 0;
  DECLARE v_n           INT DEFAULT 0;
  DECLARE v_item        INT;
  DECLARE v_qty         DECIMAL(12,3);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  -- ------------------------------------------------------------ header checks
  SELECT IF(s.state_code <> (SELECT state_code FROM shop_settings WHERE id = 1), 1, 0), s.payment_terms_days, s.supplier_name
    INTO v_inter, v_terms, v_supp_name
    FROM suppliers s WHERE s.id = p_supplier_id AND s.is_deleted = 0;
  IF v_supp_name IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'supplierId::Supplier not found';
  END IF;
  IF p_pe_date IS NULL OR p_pe_date > CURDATE() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'peDate::PE date is required and cannot be in the future';
  END IF;
  IF v_invoice = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invoiceNo::Supplier invoice no. is required';
  END IF;
  IF p_invoice_date IS NULL OR p_invoice_date > p_pe_date THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invoiceDate::Invoice date is required and cannot be after the PE date';
  END IF;
  IF EXISTS (SELECT 1 FROM purchase_entries WHERE supplier_id = p_supplier_id AND supplier_invoice_no = v_invoice
                                              AND id <> v_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45409' SET MESSAGE_TEXT = 'invoiceNo::This invoice number is already entered for this supplier';
  END IF;

  IF v_id > 0 THEN
    SELECT supplier_id, po_id, grand_total, paid_amount, DATE(created_at)
      INTO v_old_supp, v_old_po, v_old_grand, v_old_paid, v_created
      FROM purchase_entries WHERE id = v_id AND is_deleted = 0;
    IF v_old_supp IS NULL THEN
      SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Purchase entry not found';
    END IF;
    IF v_created <> CURDATE() THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Purchase entries can only be edited on the day they were created';
    END IF;
    IF v_old_supp <> p_supplier_id THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'supplierId::The supplier cannot be changed after saving';
    END IF;
  END IF;

  IF v_po IS NOT NULL THEN
    SELECT supplier_id, po_status INTO v_po_supplier, v_po_status FROM purchase_orders WHERE id = v_po AND is_deleted = 0;
    IF v_po_supplier IS NULL OR v_po_supplier <> p_supplier_id THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'poId::Selected PO does not belong to this supplier';
    END IF;
    IF v_po_status NOT IN ('SENT', 'PARTIAL') AND NOT (v_po = IFNULL(v_old_po, 0) AND v_po_status = 'RECEIVED') THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'poId::This purchase order is not open for receiving';
    END IF;
  END IF;

  -- ------------------------------------------------------------ lines
  DROP TEMPORARY TABLE IF EXISTS tmp_pe_items;
  CREATE TEMPORARY TABLE tmp_pe_items (
    line_no      INT NOT NULL PRIMARY KEY,
    item_id      INT NULL,
    item_name    VARCHAR(60) NULL,
    po_item_id   INT NULL,
    ordered_qty  DECIMAL(12,3) NULL,
    received_qty DECIMAL(12,3) NULL,
    rate         DECIMAL(12,2) NULL,
    gst_pct      DECIMAL(5,2) NULL,
    expiry_date  DATE NULL,
    amount       DECIMAL(12,2) NOT NULL DEFAULT 0,
    gst_amount   DECIMAL(12,2) NOT NULL DEFAULT 0,
    valid        TINYINT NOT NULL DEFAULT 0
  ) ENGINE=MEMORY;

  INSERT INTO tmp_pe_items (line_no, item_id, ordered_qty, received_qty, rate, gst_pct, expiry_date)
  SELECT jt.line_no, jt.item_id, jt.ordered_qty, ROUND(jt.received_qty, 3), ROUND(jt.rate, 2), jt.gst_pct, jt.expiry_date
    FROM JSON_TABLE(IFNULL(p_items, JSON_ARRAY()), '$[*]' COLUMNS (
           line_no      FOR ORDINALITY,
           item_id      INT           PATH '$.itemId'      NULL ON EMPTY,
           ordered_qty  DECIMAL(12,3) PATH '$.orderedQty'  NULL ON EMPTY,
           received_qty DECIMAL(12,3) PATH '$.receivedQty' NULL ON EMPTY,
           rate         DECIMAL(12,2) PATH '$.rate'        NULL ON EMPTY,
           gst_pct      DECIMAL(5,2)  PATH '$.gstPercent'  NULL ON EMPTY,
           expiry_date  DATE          PATH '$.expiryDate'  NULL ON EMPTY
         )) AS jt;

  UPDATE tmp_pe_items t JOIN items i ON i.id = t.item_id
     SET t.item_name = i.item_name, t.gst_pct = IFNULL(t.gst_pct, i.gst_pct),
         t.valid = IF(i.is_deleted = 0 AND i.item_type IN ('RAW', 'BOTH'), 1, 0);

  SELECT COUNT(*), COUNT(DISTINCT item_id), IFNULL(SUM(valid = 0), 0),
         IFNULL(SUM(IFNULL(received_qty, 0) <= 0 OR IFNULL(rate, 0) <= 0), 0),
         IFNULL(SUM(IFNULL(gst_pct, -1) NOT IN (0, 5, 12, 18, 28)), 0)
    INTO v_count, v_distinct, v_invalid, v_bad_qty, v_bad_gst
    FROM tmp_pe_items;

  IF v_count = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::Add at least one item';
  END IF;
  IF v_distinct <> v_count THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::Each item can be added only once';
  END IF;
  IF v_invalid > 0 THEN
    SELECT item_name INTO v_bad_name FROM tmp_pe_items WHERE valid = 0 ORDER BY line_no LIMIT 1;
    SET v_msg = LEFT(CONCAT('items::', IFNULL(v_bad_name, 'An item'), ' is a sale-only item or no longer exists'), 128);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF v_bad_qty > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::Received quantity and rate must be greater than 0';
  END IF;
  IF v_bad_gst > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::GST % must be one of 0, 5, 12, 18, 28';
  END IF;

  UPDATE tmp_pe_items SET amount = ROUND(received_qty * rate, 2);
  UPDATE tmp_pe_items SET gst_amount = ROUND(amount * gst_pct / 100, 2);
  SELECT IFNULL(SUM(amount), 0), IFNULL(SUM(gst_amount), 0) INTO v_sub, v_gst FROM tmp_pe_items;

  IF v_inter = 1 THEN
    SET v_igst = v_gst;
  ELSE
    SET v_cgst = ROUND(v_gst / 2, 2);
    SET v_sgst = v_gst - v_cgst;
  END IF;
  SET v_exact = v_sub + v_gst - v_discount + v_other;
  SET v_grand = GREATEST(ROUND(v_exact, 0), 0);

  IF v_id = 0 THEN
    IF v_paid_now > v_grand THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'paidNow::Paid amount cannot exceed the grand total';
    END IF;
    IF v_paid_now > 0 AND IFNULL(p_payment_mode, '') NOT IN ('CASH', 'BANK', 'UPI', 'CHEQUE') THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'paymentMode::Select a payment mode';
    END IF;
    SET v_paid = v_paid_now;
  ELSE
    SET v_paid = v_old_paid;
    IF v_paid > v_grand THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Grand total cannot be less than the amount already paid';
    END IF;
  END IF;

  START TRANSACTION;

  -- ------------------------------------------------ edit: undo the old entry
  IF v_id > 0 THEN
    SELECT id INTO v_i FROM purchase_entries WHERE id = v_id FOR UPDATE;

    DROP TEMPORARY TABLE IF EXISTS tmp_pe_old;
    CREATE TEMPORARY TABLE tmp_pe_old (
      seq INT NOT NULL AUTO_INCREMENT PRIMARY KEY, item_id INT NOT NULL, qty DECIMAL(12,3) NOT NULL
    ) ENGINE=MEMORY;
    INSERT INTO tmp_pe_old (item_id, qty)
    SELECT item_id, SUM(received_qty) FROM purchase_entry_items WHERE pe_id = v_id GROUP BY item_id ORDER BY item_id;

    SELECT COUNT(*) INTO v_n FROM tmp_pe_old;
    SET v_i = 1;
    WHILE v_i <= v_n DO
      SELECT item_id, qty INTO v_item, v_qty FROM tmp_pe_old WHERE seq = v_i;
      CALL sp_util_stock_post(v_item, 'PE_EDIT', 'purchase_entries', v_id, 0, v_qty, p_user_id);
      SET v_i = v_i + 1;
    END WHILE;

    UPDATE purchase_order_items pi
      JOIN (SELECT po_item_id, SUM(received_qty) AS q FROM purchase_entry_items
             WHERE pe_id = v_id AND po_item_id IS NOT NULL GROUP BY po_item_id) x ON x.po_item_id = pi.id
       SET pi.received_qty = GREATEST(pi.received_qty - x.q, 0);
    CALL sp_po_refresh_status(v_old_po, p_user_id);

    DELETE FROM purchase_entry_items WHERE pe_id = v_id;
    DROP TEMPORARY TABLE IF EXISTS tmp_pe_old;
  END IF;

  -- ------------------------------------------------ header
  IF v_id = 0 THEN
    CALL sp_util_next_number('PE', v_pe_no);
    INSERT INTO purchase_entries (pe_no, pe_date, supplier_id, po_id, supplier_invoice_no, invoice_date, invoice_file_url,
                                  invoice_file_name, sub_total, cgst, sgst, igst, discount, other_charges, round_off,
                                  grand_total, paid_amount, balance, due_date, payment_status, created_by)
    VALUES (v_pe_no, p_pe_date, p_supplier_id, v_po, v_invoice, p_invoice_date, p_invoice_file_url,
            p_invoice_file_name, v_sub, v_cgst, v_sgst, v_igst, v_discount, v_other, v_grand - v_exact,
            v_grand, v_paid, v_grand - v_paid, p_invoice_date + INTERVAL v_terms DAY,
            CASE WHEN v_paid <= 0 THEN 'UNPAID' WHEN v_paid >= v_grand THEN 'PAID' ELSE 'PARTIAL' END, p_user_id);
    SET v_id = LAST_INSERT_ID();
  ELSE
    SELECT pe_no INTO v_pe_no FROM purchase_entries WHERE id = v_id;
    UPDATE purchase_entries
       SET pe_date = p_pe_date, po_id = v_po, supplier_invoice_no = v_invoice, invoice_date = p_invoice_date,
           invoice_file_url = p_invoice_file_url, invoice_file_name = p_invoice_file_name,
           sub_total = v_sub, cgst = v_cgst, sgst = v_sgst, igst = v_igst, discount = v_discount,
           other_charges = v_other, round_off = v_grand - v_exact, grand_total = v_grand,
           balance = v_grand - paid_amount, due_date = p_invoice_date + INTERVAL v_terms DAY,
           payment_status = CASE WHEN paid_amount <= 0 THEN 'UNPAID' WHEN paid_amount >= v_grand THEN 'PAID' ELSE 'PARTIAL' END,
           updated_by = p_user_id, updated_at = NOW()
     WHERE id = v_id;
  END IF;

  -- ------------------------------------------------ lines, stock, PO progress
  IF v_po IS NOT NULL THEN
    UPDATE tmp_pe_items t
      JOIN purchase_order_items pi ON pi.po_id = v_po AND pi.item_id = t.item_id
       SET t.po_item_id = pi.id, t.ordered_qty = IFNULL(t.ordered_qty, pi.qty);
  END IF;

  INSERT INTO purchase_entry_items (pe_id, po_item_id, item_id, ordered_qty, received_qty, rate, gst_pct, expiry_date,
                                    amount, cgst, sgst, igst)
  SELECT v_id, po_item_id, item_id, ordered_qty, received_qty, rate, gst_pct, expiry_date, amount,
         IF(v_inter = 1, 0, ROUND(gst_amount / 2, 2)),
         IF(v_inter = 1, 0, gst_amount - ROUND(gst_amount / 2, 2)),
         IF(v_inter = 1, gst_amount, 0)
    FROM tmp_pe_items ORDER BY line_no;

  DROP TEMPORARY TABLE IF EXISTS tmp_pe_stock;
  CREATE TEMPORARY TABLE tmp_pe_stock (
    seq INT NOT NULL AUTO_INCREMENT PRIMARY KEY, item_id INT NOT NULL, qty DECIMAL(12,3) NOT NULL
  ) ENGINE=MEMORY;
  INSERT INTO tmp_pe_stock (item_id, qty)
  SELECT item_id, received_qty FROM tmp_pe_items ORDER BY item_id;

  SELECT COUNT(*) INTO v_n FROM tmp_pe_stock;
  SET v_i = 1;
  WHILE v_i <= v_n DO
    SELECT item_id, qty INTO v_item, v_qty FROM tmp_pe_stock WHERE seq = v_i;
    CALL sp_util_stock_post(v_item, 'PURCHASE', 'purchase_entries', v_id, v_qty, 0, p_user_id);
    SET v_i = v_i + 1;
  END WHILE;

  UPDATE items i JOIN tmp_pe_items t ON t.item_id = i.id
     SET i.purchase_price = t.rate, i.updated_at = NOW();

  IF v_po IS NOT NULL THEN
    UPDATE purchase_order_items pi JOIN tmp_pe_items t ON t.po_item_id = pi.id
       SET pi.received_qty = pi.received_qty + t.received_qty;
    CALL sp_po_refresh_status(v_po, p_user_id);
  END IF;

  -- ------------------------------------------------ supplier balance and payment
  IF IFNULL(p_id, 0) = 0 THEN
    UPDATE suppliers SET current_balance = current_balance + v_grand - v_paid_now WHERE id = p_supplier_id;
    IF v_paid_now > 0 THEN
      INSERT INTO supplier_payments (supplier_id, pe_id, payment_date, amount, payment_mode, reference_no, created_by)
      VALUES (p_supplier_id, v_id, p_pe_date, v_paid_now, p_payment_mode, NULL, p_user_id);
      IF p_payment_mode = 'CASH' THEN
        CALL sp_util_next_number('TXN', v_txn_no);
        INSERT INTO transactions (txn_no, txn_date, txn_type, payment_mode, amount, purchase_entry_id, remarks, user_id)
        VALUES (v_txn_no, NOW(), 'CASH_OUT', 'CASH', v_paid_now, v_id,
                LEFT(CONCAT('Supplier payment - ', v_supp_name, ' (', v_pe_no, ')'), 200), p_user_id);
      END IF;
    END IF;
  ELSE
    UPDATE suppliers SET current_balance = current_balance + (v_grand - v_old_grand) WHERE id = p_supplier_id;
    CALL sp_util_audit(p_user_id, 'EDIT', 'purchase_entries', v_id, JSON_OBJECT('grandTotal', v_old_grand, 'poId', v_old_po),
                       JSON_OBJECT('grandTotal', v_grand, 'poId', v_po));
  END IF;

  COMMIT;
  DROP TEMPORARY TABLE IF EXISTS tmp_pe_items, tmp_pe_stock;

  SELECT v_id AS id, CONCAT('Purchase entry ', v_pe_no, ' saved') AS message;
END
