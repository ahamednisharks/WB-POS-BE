-- sp_combo_save
-- Purpose : Insert (p_id = 0) or update a combo and its component items.
--           actual_price = sum(item selling price x qty) is computed here; component prices are snapshotted.
--           p_gst_pct NULL -> highest GST among the components.
-- Params  : p_id, p_name, p_combo_price, p_gst_pct, p_valid_from, p_valid_to, p_image_url, p_status,
--           p_items JSON [{ "itemId": 1, "qty": 2 }], p_user_id
-- Results : (1) id, message
-- Errors  : 45000 validation (>= 2 items, combo price < actual price ...), 45404 not found, 45409 duplicate name
CREATE PROCEDURE sp_combo_save(
  IN p_id          INT,
  IN p_name        VARCHAR(60),
  IN p_combo_price DECIMAL(12,2),
  IN p_gst_pct     DECIMAL(5,2),
  IN p_valid_from  DATE,
  IN p_valid_to    DATE,
  IN p_image_url   VARCHAR(255),
  IN p_status      TINYINT,
  IN p_items       JSON,
  IN p_user_id     INT
)
BEGIN
  DECLARE v_id       INT DEFAULT IFNULL(p_id, 0);
  DECLARE v_name     VARCHAR(60) DEFAULT TRIM(IFNULL(p_name, ''));
  DECLARE v_price    DECIMAL(12,2) DEFAULT ROUND(IFNULL(p_combo_price, 0), 2);
  DECLARE v_count    INT DEFAULT 0;
  DECLARE v_distinct INT DEFAULT 0;
  DECLARE v_invalid  INT DEFAULT 0;
  DECLARE v_bad_qty  INT DEFAULT 0;
  DECLARE v_actual   DECIMAL(12,2) DEFAULT 0;
  DECLARE v_gst      DECIMAL(5,2) DEFAULT p_gst_pct;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; DROP TEMPORARY TABLE IF EXISTS tmp_combo_items; RESIGNAL; END;

  IF v_name = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'name::Combo name is required';
  END IF;
  IF EXISTS (SELECT 1 FROM combos WHERE combo_name = v_name AND id <> v_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45409' SET MESSAGE_TEXT = 'name::A combo with this name already exists';
  END IF;
  IF p_valid_from IS NOT NULL AND p_valid_to IS NOT NULL AND p_valid_to < p_valid_from THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'validTo::Valid To must be on or after Valid From';
  END IF;

  DROP TEMPORARY TABLE IF EXISTS tmp_combo_items;
  CREATE TEMPORARY TABLE tmp_combo_items (
    item_id INT NULL,
    qty     DECIMAL(12,3) NULL,
    price   DECIMAL(12,2) NULL,
    gst_pct DECIMAL(5,2) NULL,
    valid   TINYINT NOT NULL DEFAULT 0
  ) ENGINE=MEMORY;

  INSERT INTO tmp_combo_items (item_id, qty)
  SELECT jt.item_id, ROUND(jt.qty, 3)
    FROM JSON_TABLE(IFNULL(p_items, JSON_ARRAY()), '$[*]' COLUMNS (
           item_id INT           PATH '$.itemId' NULL ON EMPTY,
           qty     DECIMAL(12,3) PATH '$.qty'    NULL ON EMPTY
         )) AS jt;

  UPDATE tmp_combo_items t
    JOIN items i ON i.id = t.item_id
     SET t.price = i.selling_price, t.gst_pct = i.gst_pct,
         t.valid = IF(i.is_deleted = 0 AND i.item_type IN ('SALE', 'BOTH'), 1, 0);

  SELECT COUNT(*), COUNT(DISTINCT item_id), SUM(valid = 0), SUM(IFNULL(qty, 0) <= 0),
         ROUND(IFNULL(SUM(IFNULL(price, 0) * IFNULL(qty, 0)), 0), 2), MAX(gst_pct)
    INTO v_count, v_distinct, v_invalid, v_bad_qty, v_actual, v_gst
    FROM tmp_combo_items;

  IF p_gst_pct IS NOT NULL THEN
    SET v_gst = p_gst_pct;
  END IF;

  IF v_count < 2 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::A combo needs at least 2 items';
  END IF;
  IF v_distinct <> v_count THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::Each item can be added only once';
  END IF;
  IF v_invalid > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::One of the combo items is not a sale item or no longer exists';
  END IF;
  IF v_bad_qty > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::Quantity must be greater than 0';
  END IF;
  IF v_price <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'comboPrice::Combo price must be greater than 0';
  END IF;
  IF v_price >= v_actual THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'comboPrice::Combo price must be less than the actual price';
  END IF;
  IF IFNULL(v_gst, -1) NOT IN (0, 5, 12, 18, 28) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'gstPercent::GST % must be one of 0, 5, 12, 18, 28';
  END IF;

  START TRANSACTION;

  IF v_id = 0 THEN
    INSERT INTO combos (combo_name, combo_price, actual_price, gst_pct, valid_from, valid_to, image_url, status, created_by)
    VALUES (v_name, v_price, v_actual, v_gst, p_valid_from, p_valid_to, p_image_url, IFNULL(p_status, 1), p_user_id);
    SET v_id = LAST_INSERT_ID();
  ELSE
    IF NOT EXISTS (SELECT 1 FROM combos WHERE id = v_id AND is_deleted = 0 FOR UPDATE) THEN
      SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Combo not found';
    END IF;
    UPDATE combos
       SET combo_name = v_name, combo_price = v_price, actual_price = v_actual, gst_pct = v_gst,
           valid_from = p_valid_from, valid_to = p_valid_to, image_url = p_image_url, status = IFNULL(p_status, 1),
           updated_by = p_user_id, updated_at = NOW()
     WHERE id = v_id;
    DELETE FROM combo_items WHERE combo_id = v_id;
  END IF;

  INSERT INTO combo_items (combo_id, item_id, qty, price)
  SELECT v_id, item_id, qty, price FROM tmp_combo_items;

  COMMIT;
  DROP TEMPORARY TABLE IF EXISTS tmp_combo_items;

  SELECT v_id AS id, 'Combo saved successfully' AS message;
END
