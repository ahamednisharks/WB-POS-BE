-- sp_item_save
-- Purpose : Insert (p_id = 0) or update (p_id > 0) an item. Blank code -> next ITM0001 style code.
--           purchase_price and current_stock are maintained by purchases / sales, never by this SP.
--           Selling price / GST changes are written to audit_log.
-- Params  : p_id, p_item_code, p_item_name, p_item_type, p_category_id, p_unit_id, p_selling_price, p_gst_pct,
--           p_price_includes_gst, p_hsn_code, p_barcode, p_min_stock, p_image_url, p_status, p_user_id
-- Results : (1) id, message
-- Errors  : 45000 validation, 45404 not found, 45409 duplicate code / name / barcode
CREATE PROCEDURE sp_item_save(
  IN p_id                 INT,
  IN p_item_code          VARCHAR(20),
  IN p_item_name          VARCHAR(60),
  IN p_item_type          VARCHAR(4),
  IN p_category_id        INT,
  IN p_unit_id            INT,
  IN p_selling_price      DECIMAL(12,2),
  IN p_gst_pct            DECIMAL(5,2),
  IN p_price_includes_gst TINYINT,
  IN p_hsn_code           VARCHAR(8),
  IN p_barcode            VARCHAR(40),
  IN p_min_stock          DECIMAL(12,3),
  IN p_image_url          VARCHAR(255),
  IN p_status             TINYINT,
  IN p_user_id            INT
)
BEGIN
  DECLARE v_id        INT DEFAULT IFNULL(p_id, 0);
  DECLARE v_code      VARCHAR(20) DEFAULT UPPER(TRIM(IFNULL(p_item_code, '')));
  DECLARE v_name      VARCHAR(60) DEFAULT TRIM(IFNULL(p_item_name, ''));
  DECLARE v_barcode   VARCHAR(40) DEFAULT NULLIF(TRIM(IFNULL(p_barcode, '')), '');
  DECLARE v_hsn       VARCHAR(8)  DEFAULT NULLIF(TRIM(IFNULL(p_hsn_code, '')), '');
  DECLARE v_price     DECIMAL(12,2) DEFAULT ROUND(IFNULL(p_selling_price, 0), 2);
  DECLARE v_old_price DECIMAL(12,2);
  DECLARE v_old_gst   DECIMAL(5,2);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF v_name = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'name::Item name is required';
  END IF;
  IF IFNULL(p_item_type, '') NOT IN ('SALE', 'RAW', 'BOTH') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'type::Item type must be SALE, RAW or BOTH';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM categories WHERE id = p_category_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'categoryId::Category not found';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM units WHERE id = p_unit_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'unitId::Unit not found';
  END IF;
  IF p_item_type <> 'RAW' AND v_price <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'sellingPrice::Selling price is required for sale items';
  END IF;
  IF IFNULL(p_gst_pct, -1) NOT IN (0, 5, 12, 18, 28) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'gstPercent::GST % must be one of 0, 5, 12, 18, 28';
  END IF;
  IF v_hsn IS NOT NULL AND v_hsn NOT REGEXP '^[0-9]{4,8}$' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'hsnCode::HSN code must be 4 to 8 digits';
  END IF;
  IF IFNULL(p_min_stock, 0) < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'minStock::Minimum stock cannot be negative';
  END IF;
  IF EXISTS (SELECT 1 FROM items WHERE item_name = v_name AND id <> v_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45409' SET MESSAGE_TEXT = 'name::An item with this name already exists';
  END IF;
  IF v_code <> '' AND EXISTS (SELECT 1 FROM items WHERE item_code = v_code AND id <> v_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45409' SET MESSAGE_TEXT = 'code::This item code is already used';
  END IF;
  IF v_barcode IS NOT NULL AND EXISTS (SELECT 1 FROM items WHERE barcode = v_barcode AND id <> v_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45409' SET MESSAGE_TEXT = 'barcode::This barcode is already assigned to another item';
  END IF;

  IF p_item_type = 'RAW' THEN
    SET v_price = 0;
  END IF;

  START TRANSACTION;

  IF v_id = 0 THEN
    IF v_code = '' THEN
      CALL sp_util_next_number('ITM', v_code);
      WHILE EXISTS (SELECT 1 FROM items WHERE item_code = v_code AND is_deleted = 0) DO
        CALL sp_util_next_number('ITM', v_code);
      END WHILE;
    END IF;

    INSERT INTO items (item_code, item_name, item_type, category_id, unit_id, selling_price, gst_pct,
                       price_includes_gst, hsn_code, barcode, min_stock, image_url, status, created_by)
    VALUES (v_code, v_name, p_item_type, p_category_id, p_unit_id, v_price, p_gst_pct,
            IFNULL(p_price_includes_gst, 1), v_hsn, v_barcode, IFNULL(p_min_stock, 0), p_image_url, IFNULL(p_status, 1), p_user_id);
    SET v_id = LAST_INSERT_ID();
  ELSE
    SELECT selling_price, gst_pct INTO v_old_price, v_old_gst
      FROM items WHERE id = v_id AND is_deleted = 0 FOR UPDATE;
    IF v_old_price IS NULL THEN
      SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Item not found';
    END IF;
    IF v_code = '' THEN
      SELECT item_code INTO v_code FROM items WHERE id = v_id;
    END IF;

    UPDATE items
       SET item_code = v_code, item_name = v_name, item_type = p_item_type, category_id = p_category_id,
           unit_id = p_unit_id, selling_price = v_price, gst_pct = p_gst_pct,
           price_includes_gst = IFNULL(p_price_includes_gst, 1), hsn_code = v_hsn, barcode = v_barcode,
           min_stock = IFNULL(p_min_stock, 0), image_url = p_image_url, status = IFNULL(p_status, 1),
           updated_by = p_user_id, updated_at = NOW()
     WHERE id = v_id;

    IF v_old_price <> v_price OR v_old_gst <> p_gst_pct THEN
      CALL sp_util_audit(p_user_id, 'PRICE_CHANGE', 'items', v_id,
                         JSON_OBJECT('sellingPrice', v_old_price, 'gstPercent', v_old_gst),
                         JSON_OBJECT('sellingPrice', v_price, 'gstPercent', p_gst_pct));
    END IF;
  END IF;

  COMMIT;

  SELECT v_id AS id, 'Item saved successfully' AS message;
END
