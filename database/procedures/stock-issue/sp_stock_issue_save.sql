-- sp_stock_issue_save
-- Purpose : Records raw material taken out of the warehouse (sent to production, wastage, expired, damaged, other)
--           in one transaction. One line per item; every line posts stock OUT (stock_ledger ISSUE) at the item's
--           last purchase rate, which sp_util_stock_post refuses when the item has not enough stock.
--           Edit (p_id > 0) is allowed on the day of entry only, by the user who created it or any ADMIN:
--           the old lines are reversed (ISSUE_CANCEL) and the new ones posted.
-- Params  : p_id (0 = new), p_issue_date, p_remarks,
--           p_items JSON [{ "itemId": 7, "qty": 2.5, "reason": "PRODUCTION", "remarks": "morning batch" }]
--             reason: PRODUCTION (default) | WASTAGE | EXPIRED | DAMAGED | OTHER (remarks required for OTHER),
--           p_user_id, p_role (ADMIN|CASHIER)
-- Results : (1) id, message
-- Errors  : 45000 validation / insufficient stock, 45403 not the creator, 45404 not found
CREATE PROCEDURE sp_stock_issue_save(
  IN p_id         INT,
  IN p_issue_date DATE,
  IN p_remarks    VARCHAR(200),
  IN p_items      JSON,
  IN p_user_id    INT,
  IN p_role       VARCHAR(10)
)
BEGIN
  DECLARE v_id         INT DEFAULT IFNULL(p_id, 0);
  DECLARE v_remarks    VARCHAR(200) DEFAULT NULLIF(TRIM(IFNULL(p_remarks, '')), '');
  DECLARE v_status     VARCHAR(10) DEFAULT NULL;
  DECLARE v_owner      INT DEFAULT NULL;
  DECLARE v_created    DATE DEFAULT NULL;
  DECLARE v_old_count  INT DEFAULT 0;
  DECLARE v_old_value  DECIMAL(12,2) DEFAULT 0;
  DECLARE v_count      INT DEFAULT 0;
  DECLARE v_distinct   INT DEFAULT 0;
  DECLARE v_invalid    INT DEFAULT 0;
  DECLARE v_bad_qty    INT DEFAULT 0;
  DECLARE v_bad_unit   INT DEFAULT 0;
  DECLARE v_bad_reason INT DEFAULT 0;
  DECLARE v_no_remark  INT DEFAULT 0;
  DECLARE v_value      DECIMAL(12,2) DEFAULT 0;
  DECLARE v_no         VARCHAR(20);
  DECLARE v_bad_name   VARCHAR(60) DEFAULT NULL;
  DECLARE v_msg        VARCHAR(128);
  DECLARE v_i          INT DEFAULT 0;
  DECLARE v_n          INT DEFAULT 0;
  DECLARE v_item       INT;
  DECLARE v_qty        DECIMAL(12,3);
  DECLARE v_stock      DECIMAL(12,3);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  -- ------------------------------------------------------------ header checks
  IF p_issue_date IS NULL OR p_issue_date > CURDATE() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'issueDate::Issue date is required and cannot be in the future';
  END IF;

  IF v_id > 0 THEN
    SELECT issue_status, issued_by, DATE(created_at), item_count, total_value
      INTO v_status, v_owner, v_created, v_old_count, v_old_value
      FROM stock_issues WHERE id = v_id;
    IF v_status IS NULL THEN
      SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Stock issue not found';
    END IF;
    IF v_status = 'CANCELLED' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A cancelled stock issue cannot be edited';
    END IF;
    IF v_created <> CURDATE() THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock issues can only be edited on the day they were created';
    END IF;
    IF IFNULL(p_role, '') <> 'ADMIN' AND v_owner <> p_user_id THEN
      SIGNAL SQLSTATE '45403' SET MESSAGE_TEXT = 'Only Admin can edit a stock issue created by another user';
    END IF;
  END IF;

  -- ------------------------------------------------------------ lines
  DROP TEMPORARY TABLE IF EXISTS tmp_si_items;
  CREATE TEMPORARY TABLE tmp_si_items (
    line_no       INT NOT NULL PRIMARY KEY,
    item_id       INT NULL,
    item_name     VARCHAR(60) NULL,
    allow_decimal TINYINT NOT NULL DEFAULT 1,
    qty           DECIMAL(12,3) NULL,
    reason        VARCHAR(20) NULL,
    remarks       VARCHAR(200) NULL,
    rate          DECIMAL(12,2) NOT NULL DEFAULT 0,
    amount        DECIMAL(12,2) NOT NULL DEFAULT 0,
    valid         TINYINT NOT NULL DEFAULT 0
  );

  INSERT INTO tmp_si_items (line_no, item_id, qty, reason, remarks)
  SELECT jt.line_no, jt.item_id, ROUND(jt.qty, 3),
         IF(TRIM(IFNULL(jt.reason, '')) = '', 'PRODUCTION', UPPER(TRIM(jt.reason))),
         NULLIF(TRIM(IFNULL(jt.remarks, '')), '')
    FROM JSON_TABLE(IFNULL(p_items, JSON_ARRAY()), '$[*]' COLUMNS (
           line_no FOR ORDINALITY,
           item_id INT           PATH '$.itemId'  NULL ON EMPTY,
           qty     DECIMAL(12,3) PATH '$.qty'     NULL ON EMPTY,
           reason  VARCHAR(20)   PATH '$.reason'  NULL ON EMPTY,
           remarks VARCHAR(200)  PATH '$.remarks' NULL ON EMPTY
         )) AS jt;

  UPDATE tmp_si_items t
    JOIN items i ON i.id = t.item_id
    JOIN units u ON u.id = i.unit_id
     SET t.item_name = i.item_name, t.allow_decimal = u.allow_decimal, t.rate = i.purchase_price,
         t.valid = IF(i.is_deleted = 0 AND i.status = 1 AND i.item_type IN ('RAW', 'BOTH'), 1, 0);

  SELECT COUNT(*), COUNT(DISTINCT item_id), IFNULL(SUM(valid = 0), 0),
         IFNULL(SUM(IFNULL(qty, 0) <= 0), 0),
         IFNULL(SUM(allow_decimal = 0 AND qty <> FLOOR(qty)), 0),
         IFNULL(SUM(reason NOT IN ('PRODUCTION', 'WASTAGE', 'EXPIRED', 'DAMAGED', 'OTHER')), 0),
         IFNULL(SUM(reason = 'OTHER' AND remarks IS NULL), 0)
    INTO v_count, v_distinct, v_invalid, v_bad_qty, v_bad_unit, v_bad_reason, v_no_remark
    FROM tmp_si_items;

  IF v_count = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::Add at least one item';
  END IF;
  IF v_distinct <> v_count THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::Each item can be added only once';
  END IF;
  IF v_invalid > 0 THEN
    SELECT item_name INTO v_bad_name FROM tmp_si_items WHERE valid = 0 ORDER BY line_no LIMIT 1;
    SET v_msg = LEFT(CONCAT('items::', IFNULL(v_bad_name, 'An item'), ' is not an active raw material'), 128);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF v_bad_qty > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::Quantity must be greater than 0';
  END IF;
  IF v_bad_unit > 0 THEN
    SELECT item_name INTO v_bad_name FROM tmp_si_items
     WHERE allow_decimal = 0 AND qty <> FLOOR(qty) ORDER BY line_no LIMIT 1;
    SET v_msg = LEFT(CONCAT('items::', v_bad_name, ' is counted in whole units'), 128);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF v_bad_reason > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::Reason must be Production, Wastage, Expired, Damaged or Other';
  END IF;
  IF v_no_remark > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::Remarks are required when the reason is Other';
  END IF;

  UPDATE tmp_si_items SET amount = ROUND(qty * rate, 2);
  SELECT IFNULL(SUM(amount), 0) INTO v_value FROM tmp_si_items;

  START TRANSACTION;

  -- ------------------------------------------------ edit: put the old lines back
  IF v_id > 0 THEN
    SELECT id INTO v_i FROM stock_issues WHERE id = v_id FOR UPDATE;

    DROP TEMPORARY TABLE IF EXISTS tmp_si_old;
    CREATE TEMPORARY TABLE tmp_si_old (
      seq INT NOT NULL AUTO_INCREMENT PRIMARY KEY, item_id INT NOT NULL, qty DECIMAL(12,3) NOT NULL
    );
    INSERT INTO tmp_si_old (item_id, qty)
    SELECT item_id, qty FROM stock_issue_items WHERE si_id = v_id ORDER BY item_id;

    SELECT COUNT(*) INTO v_n FROM tmp_si_old;
    SET v_i = 1;
    WHILE v_i <= v_n DO
      SELECT item_id, qty INTO v_item, v_qty FROM tmp_si_old WHERE seq = v_i;
      CALL sp_util_stock_post(v_item, 'ISSUE_CANCEL', 'stock_issues', v_id, v_qty, 0, p_user_id);
      SET v_i = v_i + 1;
    END WHILE;

    DELETE FROM stock_issue_items WHERE si_id = v_id;
    DROP TEMPORARY TABLE IF EXISTS tmp_si_old;
  END IF;

  -- ------------------------------------------------ header
  IF v_id = 0 THEN
    CALL sp_util_next_number('STI', v_no);
    INSERT INTO stock_issues (issue_no, issue_date, remarks, item_count, total_value, issued_by, created_by)
    VALUES (v_no, p_issue_date, v_remarks, v_count, v_value, p_user_id, p_user_id);
    SET v_id = LAST_INSERT_ID();
  ELSE
    SELECT issue_no INTO v_no FROM stock_issues WHERE id = v_id;
    UPDATE stock_issues
       SET issue_date = p_issue_date, remarks = v_remarks, item_count = v_count, total_value = v_value,
           updated_by = p_user_id, updated_at = NOW()
     WHERE id = v_id;
  END IF;

  -- ------------------------------------------------ lines and stock
  INSERT INTO stock_issue_items (si_id, line_no, item_id, qty, reason, rate, amount, remarks)
  SELECT v_id, line_no, item_id, qty, reason, rate, amount, remarks
    FROM tmp_si_items ORDER BY line_no;

  DROP TEMPORARY TABLE IF EXISTS tmp_si_stock;
  CREATE TEMPORARY TABLE tmp_si_stock (
    seq INT NOT NULL AUTO_INCREMENT PRIMARY KEY, item_id INT NOT NULL, qty DECIMAL(12,3) NOT NULL
  );
  INSERT INTO tmp_si_stock (item_id, qty)
  SELECT item_id, qty FROM tmp_si_items ORDER BY item_id;

  SELECT COUNT(*) INTO v_n FROM tmp_si_stock;
  SET v_i = 1;
  WHILE v_i <= v_n DO
    SELECT item_id, qty INTO v_item, v_qty FROM tmp_si_stock WHERE seq = v_i;
    -- An issue can never take out more than is in stock, whatever shop_settings.allow_negative_stock says
    -- (sp_util_stock_post only enforces that for RAW items; BOTH items may go negative on sales).
    SELECT current_stock, item_name INTO v_stock, v_bad_name FROM items WHERE id = v_item FOR UPDATE;
    IF v_stock < v_qty THEN
      SET v_msg = LEFT(CONCAT('Insufficient stock for ', v_bad_name, ' (available ',
                              TRIM(TRAILING '.' FROM TRIM(TRAILING '0' FROM v_stock)), ')'), 128);
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    CALL sp_util_stock_post(v_item, 'ISSUE', 'stock_issues', v_id, 0, v_qty, p_user_id);
    SET v_i = v_i + 1;
  END WHILE;

  IF IFNULL(p_id, 0) > 0 THEN
    CALL sp_util_audit(p_user_id, 'EDIT', 'stock_issues', v_id,
                       JSON_OBJECT('itemCount', v_old_count, 'totalValue', v_old_value),
                       JSON_OBJECT('itemCount', v_count, 'totalValue', v_value));
  END IF;

  COMMIT;
  DROP TEMPORARY TABLE IF EXISTS tmp_si_items, tmp_si_stock;

  SELECT v_id AS id, CONCAT('Stock issue ', v_no, ' saved') AS message;
END
