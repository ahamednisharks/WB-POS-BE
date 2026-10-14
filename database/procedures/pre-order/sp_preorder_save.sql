-- sp_preorder_save
-- Purpose : Creates a pre-order (p_id = 0) or edits a BOOKED / READY one (p_id > 0), taking any new payments in the
--           same call. Each line's rate is the agreed "Item Price" sent by the client (cashiers may change it); the
--           Item Master price is stored as master_rate ("Actual Price") when the item is first put on the order and
--           kept on later edits. Totals follow sp_bill_save with an AMOUNT discount:
--             line_amount = qty x rate; the discount is apportioned to lines by line_amount, the last line takes the
--             rounding remainder; price-includes-GST lines back-calculate tax, others add it; CGST = round(GST / 2),
--             SGST = GST - CGST; grand total = taxable + GST + delivery charge (not taxed), rounded to the rupee.
--           CASHIER discount is capped by shop_settings.cashier_max_discount_pct. PICKUP orders carry no address or
--           delivery charge. The customer is registered by mobile (name only - visit totals move on delivery).
--           No stock moves and no bill is created until delivery. An edit cannot take the total below what is paid.
-- Params  : p_id, p_customer_mobile, p_customer_name, p_alt_mobile, p_delivery_at, p_delivery_type (PICKUP|HOME),
--           p_delivery_address, p_delivery_charge, p_discount_amount,
--           p_items JSON [{ "itemId": 1, "qty": 1.5, "rate": 500, "notes": "Happy Birthday", "designUrl": "/uploads/..." }],
--           p_payments JSON [{ "mode": "CASH", "amount": 400, "referenceNo": null }] (new payments only),
--           p_user_id, p_role
-- Results : the saved pre-order, as sp_preorder_get: (1) header, (2) lines, (3) payments
-- Errors  : 45000 validation, 45403 discount above cashier limit, 45404 pre-order not found
CREATE PROCEDURE sp_preorder_save(
  IN p_id               INT,
  IN p_customer_mobile  VARCHAR(10),
  IN p_customer_name    VARCHAR(80),
  IN p_alt_mobile       VARCHAR(10),
  IN p_delivery_at      DATETIME,
  IN p_delivery_type    VARCHAR(10),
  IN p_delivery_address VARCHAR(255),
  IN p_delivery_charge  DECIMAL(12,2),
  IN p_discount_amount  DECIMAL(12,2),
  IN p_items            JSON,
  IN p_payments         JSON,
  IN p_user_id          INT,
  IN p_role             VARCHAR(10)
)
BEGIN
  DECLARE v_id          INT DEFAULT IFNULL(p_id, 0);
  DECLARE v_old_status  VARCHAR(10) DEFAULT NULL;
  DECLARE v_old_at      DATETIME DEFAULT NULL;
  DECLARE v_paid        DECIMAL(12,2) DEFAULT 0;
  DECLARE v_order_no    VARCHAR(20) DEFAULT NULL;
  DECLARE v_customer_id INT DEFAULT NULL;
  DECLARE v_mobile      VARCHAR(10) DEFAULT NULLIF(TRIM(IFNULL(p_customer_mobile, '')), '');
  DECLARE v_name        VARCHAR(80) DEFAULT NULLIF(TRIM(IFNULL(p_customer_name, '')), '');
  DECLARE v_alt         VARCHAR(10) DEFAULT NULLIF(TRIM(IFNULL(p_alt_mobile, '')), '');
  DECLARE v_type        VARCHAR(10) DEFAULT UPPER(TRIM(IFNULL(p_delivery_type, 'PICKUP')));
  DECLARE v_address     VARCHAR(255) DEFAULT NULLIF(TRIM(IFNULL(p_delivery_address, '')), '');
  DECLARE v_charge      DECIMAL(12,2) DEFAULT ROUND(IFNULL(p_delivery_charge, 0), 2);
  DECLARE v_discount    DECIMAL(12,2) DEFAULT ROUND(IFNULL(p_discount_amount, 0), 2);
  DECLARE v_lines       INT DEFAULT 0;
  DECLARE v_last        INT DEFAULT 0;
  DECLARE v_bad_line    INT DEFAULT NULL;
  DECLARE v_bad_name    VARCHAR(100) DEFAULT NULL;
  DECLARE v_sub         DECIMAL(12,2) DEFAULT 0;
  DECLARE v_alloc       DECIMAL(12,2) DEFAULT 0;
  DECLARE v_max_pct     DECIMAL(5,2) DEFAULT 10;
  DECLARE v_taxable     DECIMAL(12,2) DEFAULT 0;
  DECLARE v_gst         DECIMAL(12,2) DEFAULT 0;
  DECLARE v_cgst        DECIMAL(12,2) DEFAULT 0;
  DECLARE v_sgst        DECIMAL(12,2) DEFAULT 0;
  DECLARE v_exact       DECIMAL(12,2) DEFAULT 0;
  DECLARE v_grand       DECIMAL(12,2) DEFAULT 0;
  DECLARE v_round       DECIMAL(12,2) DEFAULT 0;
  DECLARE v_pay_count   INT DEFAULT 0;
  DECLARE v_msg         VARCHAR(128);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  -- ---------------------------------------------------------- header
  IF v_mobile IS NULL OR v_mobile NOT REGEXP '^[6-9][0-9]{9}$' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'customerMobile::Customer mobile must be a valid 10-digit number';
  END IF;
  IF v_name IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'customerName::Customer name is required';
  END IF;
  IF v_alt IS NOT NULL AND v_alt NOT REGEXP '^[6-9][0-9]{9}$' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'altMobile::Additional phone must be a valid 10-digit number';
  END IF;
  IF v_alt = v_mobile THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'altMobile::Additional phone must be different from the customer mobile';
  END IF;
  IF p_delivery_at IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'deliveryAt::Delivery date & time is required';
  END IF;
  IF v_type NOT IN ('PICKUP', 'HOME') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'deliveryType::Delivery type must be PICKUP or HOME';
  END IF;
  IF v_type = 'HOME' AND v_address IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'deliveryAddress::Delivery address is required for home delivery';
  END IF;
  IF v_charge < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'deliveryCharge::Delivery charge cannot be negative';
  END IF;
  IF v_discount < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'discountAmount::Discount cannot be negative';
  END IF;
  IF v_type = 'PICKUP' THEN
    SET v_address = NULL, v_charge = 0;
  END IF;

  IF v_id > 0 THEN
    SELECT order_status, delivery_at INTO v_old_status, v_old_at FROM pre_orders WHERE id = v_id AND is_deleted = 0;
    IF v_old_status IS NULL THEN
      SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Pre-order not found';
    END IF;
    IF v_old_status NOT IN ('BOOKED', 'READY') THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The pre-order was already delivered or cancelled';
    END IF;
  END IF;

  -- An overdue order can still be edited as long as its delivery time is left as it was.
  IF p_delivery_at <= NOW() AND (v_old_at IS NULL OR p_delivery_at <> v_old_at) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'deliveryAt::Delivery date & time must be in the future';
  END IF;

  -- ----------------------------------------------------------- lines
  DROP TEMPORARY TABLE IF EXISTS tmp_preorder_lines;
  CREATE TEMPORARY TABLE tmp_preorder_lines (
    line_no            INT NOT NULL PRIMARY KEY,
    item_id            INT NULL,
    qty                DECIMAL(12,3) NULL,
    rate               DECIMAL(12,2) NULL,
    notes              VARCHAR(255) NULL,
    design_url         VARCHAR(255) NULL,
    item_code          VARCHAR(20) NULL,
    item_name          VARCHAR(100) NULL,
    category_name      VARCHAR(50) NULL,
    unit_code          VARCHAR(10) NULL,
    allow_decimal      TINYINT NOT NULL DEFAULT 0,
    master_rate        DECIMAL(12,2) NOT NULL DEFAULT 0,
    gst_pct            DECIMAL(5,2) NOT NULL DEFAULT 0,
    price_includes_gst TINYINT NOT NULL DEFAULT 1,
    line_amount        DECIMAL(12,2) NOT NULL DEFAULT 0,
    discount_share     DECIMAL(12,2) NOT NULL DEFAULT 0,
    taxable_amount     DECIMAL(12,2) NOT NULL DEFAULT 0,
    gst_amount         DECIMAL(12,2) NOT NULL DEFAULT 0,
    cgst               DECIMAL(12,2) NOT NULL DEFAULT 0,
    sgst               DECIMAL(12,2) NOT NULL DEFAULT 0,
    line_total         DECIMAL(12,2) NOT NULL DEFAULT 0,
    valid              TINYINT NOT NULL DEFAULT 0
  );

  INSERT INTO tmp_preorder_lines (line_no, item_id, qty, rate, notes, design_url)
  SELECT jt.line_no, jt.item_id, ROUND(jt.qty, 3), ROUND(jt.rate, 2), NULLIF(TRIM(jt.notes), ''), NULLIF(TRIM(jt.design_url), '')
    FROM JSON_TABLE(IFNULL(p_items, JSON_ARRAY()), '$[*]' COLUMNS (
           line_no    FOR ORDINALITY,
           item_id    INT           PATH '$.itemId'    NULL ON EMPTY,
           qty        DECIMAL(12,3) PATH '$.qty'       NULL ON EMPTY,
           rate       DECIMAL(12,2) PATH '$.rate'      NULL ON EMPTY,
           notes      VARCHAR(255)  PATH '$.notes'     NULL ON EMPTY,
           design_url VARCHAR(255)  PATH '$.designUrl' NULL ON EMPTY
         )) AS jt;

  SELECT COUNT(*), IFNULL(MAX(line_no), 0) INTO v_lines, v_last FROM tmp_preorder_lines;
  IF v_lines = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::Add at least one item to the order';
  END IF;
  IF EXISTS (SELECT 1 FROM tmp_preorder_lines WHERE IFNULL(item_id, 0) <= 0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::Select an item on every line';
  END IF;
  IF EXISTS (SELECT 1 FROM tmp_preorder_lines WHERE IFNULL(qty, 0) <= 0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::Quantity must be greater than 0';
  END IF;
  IF EXISTS (SELECT 1 FROM tmp_preorder_lines WHERE IFNULL(rate, 0) <= 0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'items::Item price must be greater than 0';
  END IF;

  UPDATE tmp_preorder_lines t
    JOIN items i      ON i.id = t.item_id
    JOIN units u      ON u.id = i.unit_id
    JOIN categories c ON c.id = i.category_id
     SET t.item_code = i.item_code, t.item_name = i.item_name, t.category_name = c.category_name,
         t.unit_code = u.short_code, t.allow_decimal = u.allow_decimal, t.master_rate = i.selling_price,
         t.gst_pct = i.gst_pct, t.price_includes_gst = i.price_includes_gst,
         t.valid = IF(i.is_deleted = 0 AND i.status = 1 AND i.item_type IN ('SALE', 'BOTH'), 1, 0);

  -- Items already on this order keep their booked Actual Price and stay allowed even if since made inactive.
  IF v_id > 0 THEN
    UPDATE tmp_preorder_lines t
      JOIN (SELECT item_id, MIN(line_no) AS line_no FROM pre_order_items WHERE pre_order_id = v_id GROUP BY item_id) f
        ON f.item_id = t.item_id
      JOIN pre_order_items o ON o.pre_order_id = v_id AND o.line_no = f.line_no
       SET t.master_rate = o.master_rate, t.valid = 1;
  END IF;

  SELECT line_no, IFNULL(item_name, 'An item') INTO v_bad_line, v_bad_name
    FROM tmp_preorder_lines WHERE valid = 0 ORDER BY line_no LIMIT 1;
  IF v_bad_line IS NOT NULL THEN
    SET v_msg = LEFT(CONCAT('items::', v_bad_name, ' is not available for sale'), 128);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  SELECT line_no, item_name INTO v_bad_line, v_bad_name
    FROM tmp_preorder_lines WHERE allow_decimal = 0 AND qty <> FLOOR(qty) ORDER BY line_no LIMIT 1;
  IF v_bad_line IS NOT NULL THEN
    SET v_msg = LEFT(CONCAT('items::', v_bad_name, ' quantity must be a whole number'), 128);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  -- ---------------------------------------------------------- totals
  UPDATE tmp_preorder_lines SET line_amount = ROUND(qty * rate, 2);
  SELECT IFNULL(SUM(line_amount), 0) INTO v_sub FROM tmp_preorder_lines;

  IF v_discount > v_sub THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'discountAmount::Discount cannot be more than the items total';
  END IF;
  SELECT IFNULL(MAX(cashier_max_discount_pct), 10) INTO v_max_pct FROM shop_settings WHERE id = 1;
  IF p_role = 'CASHIER' AND v_discount > ROUND(v_sub * v_max_pct / 100, 2) THEN
    SET v_msg = CONCAT('discountAmount::Cashiers can give at most ', TRIM(TRAILING '.' FROM TRIM(TRAILING '0' FROM v_max_pct)), '% discount');
    SIGNAL SQLSTATE '45403' SET MESSAGE_TEXT = v_msg;
  END IF;

  UPDATE tmp_preorder_lines SET discount_share = IF(v_sub > 0, ROUND(v_discount * line_amount / v_sub, 2), 0);
  SELECT IFNULL(SUM(discount_share), 0) INTO v_alloc FROM tmp_preorder_lines;
  UPDATE tmp_preorder_lines SET discount_share = discount_share + (v_discount - v_alloc) WHERE line_no = v_last;

  UPDATE tmp_preorder_lines
     SET taxable_amount = IF(price_includes_gst = 1,
                             ROUND((line_amount - discount_share) * 100 / (100 + gst_pct), 2),
                             line_amount - discount_share);
  UPDATE tmp_preorder_lines
     SET gst_amount = IF(price_includes_gst = 1,
                         (line_amount - discount_share) - taxable_amount,
                         ROUND(taxable_amount * gst_pct / 100, 2));
  UPDATE tmp_preorder_lines
     SET cgst = ROUND(gst_amount / 2, 2),
         sgst = gst_amount - ROUND(gst_amount / 2, 2),
         line_total = taxable_amount + gst_amount;

  SELECT IFNULL(SUM(taxable_amount), 0), IFNULL(SUM(gst_amount), 0) INTO v_taxable, v_gst FROM tmp_preorder_lines;
  SET v_cgst  = ROUND(v_gst / 2, 2);
  SET v_sgst  = v_gst - v_cgst;
  SET v_exact = v_taxable + v_gst + v_charge;
  SET v_grand = ROUND(v_exact, 0);
  SET v_round = v_grand - v_exact;

  -- ----------------------------------------------------------- write
  START TRANSACTION;

  IF v_id > 0 THEN
    SELECT order_status, paid_amount INTO v_old_status, v_paid FROM pre_orders WHERE id = v_id FOR UPDATE;
    IF v_old_status NOT IN ('BOOKED', 'READY') THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The pre-order was already delivered or cancelled';
    END IF;
    IF v_grand < v_paid THEN
      SET v_msg = CONCAT('items::Order total ', v_grand, ' cannot be less than the amount already paid (', v_paid, ')');
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    DELETE FROM pre_order_items WHERE pre_order_id = v_id;
  END IF;

  INSERT INTO customers (mobile, customer_name) VALUES (v_mobile, v_name) AS nc
  ON DUPLICATE KEY UPDATE customer_name = nc.customer_name, updated_at = NOW();
  SELECT id INTO v_customer_id FROM customers WHERE mobile = v_mobile;

  IF v_id = 0 THEN
    CALL sp_util_next_number('PRE', v_order_no);
    INSERT INTO pre_orders (order_no, order_date, customer_id, customer_mobile, customer_name, alt_mobile, delivery_at,
                            delivery_type, delivery_address, delivery_charge, item_count, sub_total, discount_amount,
                            taxable_amount, cgst, sgst, round_off, grand_total, order_status, booked_by, created_by)
    VALUES (v_order_no, NOW(), v_customer_id, v_mobile, v_name, v_alt, p_delivery_at,
            v_type, v_address, v_charge, v_lines, v_sub, v_discount,
            v_taxable, v_cgst, v_sgst, v_round, v_grand, 'BOOKED', p_user_id, p_user_id);
    SET v_id = LAST_INSERT_ID();
  ELSE
    UPDATE pre_orders
       SET customer_id = v_customer_id, customer_mobile = v_mobile, customer_name = v_name, alt_mobile = v_alt,
           delivery_at = p_delivery_at, delivery_type = v_type, delivery_address = v_address, delivery_charge = v_charge,
           item_count = v_lines, sub_total = v_sub, discount_amount = v_discount, taxable_amount = v_taxable,
           cgst = v_cgst, sgst = v_sgst, round_off = v_round, grand_total = v_grand,
           updated_by = p_user_id, updated_at = NOW()
     WHERE id = v_id;
  END IF;

  INSERT INTO pre_order_items (pre_order_id, line_no, item_id, item_code, item_name, category_name, unit_code, allow_decimal,
                               qty, master_rate, rate, gst_pct, price_includes_gst, line_amount, discount_share,
                               taxable_amount, cgst, sgst, line_total, notes, design_url)
  SELECT v_id, line_no, item_id, item_code, item_name, category_name, unit_code, allow_decimal,
         qty, master_rate, rate, gst_pct, price_includes_gst, line_amount, discount_share,
         taxable_amount, cgst, sgst, line_total, notes, design_url
    FROM tmp_preorder_lines
   ORDER BY line_no;

  CALL sp_preorder_post_payments(v_id, p_payments, p_user_id, v_pay_count);

  COMMIT;

  DROP TEMPORARY TABLE IF EXISTS tmp_preorder_lines;

  CALL sp_preorder_get(v_id);
END
