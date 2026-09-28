-- sp_supplier_save
-- Purpose : Insert (p_id = 0, code SUP001 generated) or update a supplier.
--           Changing the opening balance moves current_balance by the same difference.
-- Params  : p_id, p_supplier_name, p_contact_person, p_mobile, p_email, p_address, p_state (name or code), p_gstin,
--           p_opening_balance, p_payment_terms_days, p_status, p_user_id
-- Results : (1) id, message
-- Errors  : 45000 validation, 45404 not found, 45409 duplicate name / GSTIN
CREATE PROCEDURE sp_supplier_save(
  IN p_id                 INT,
  IN p_supplier_name      VARCHAR(80),
  IN p_contact_person     VARCHAR(80),
  IN p_mobile             VARCHAR(10),
  IN p_email              VARCHAR(100),
  IN p_address            VARCHAR(255),
  IN p_state              VARCHAR(60),
  IN p_gstin              VARCHAR(15),
  IN p_opening_balance    DECIMAL(12,2),
  IN p_payment_terms_days INT,
  IN p_status             TINYINT,
  IN p_user_id            INT
)
BEGIN
  DECLARE v_id          INT DEFAULT IFNULL(p_id, 0);
  DECLARE v_name        VARCHAR(80) DEFAULT TRIM(IFNULL(p_supplier_name, ''));
  DECLARE v_gstin       VARCHAR(15) DEFAULT NULLIF(UPPER(TRIM(IFNULL(p_gstin, ''))), '');
  DECLARE v_state       CHAR(2) DEFAULT NULL;
  DECLARE v_code        VARCHAR(20);
  DECLARE v_opening     DECIMAL(12,2) DEFAULT ROUND(IFNULL(p_opening_balance, 0), 2);
  DECLARE v_old_opening DECIMAL(12,2);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF v_name = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'name::Supplier name is required';
  END IF;
  IF IFNULL(p_mobile, '') NOT REGEXP '^[6-9][0-9]{9}$' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'mobile::Enter a valid 10-digit mobile number';
  END IF;
  IF TRIM(IFNULL(p_address, '')) = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'address::Address is required';
  END IF;

  SELECT MAX(state_code) INTO v_state FROM states WHERE state_code = p_state OR state_name = p_state;
  IF v_state IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'state::Select a valid state';
  END IF;

  IF v_gstin IS NOT NULL THEN
    IF v_gstin NOT REGEXP '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'gstin::Enter a valid 15-character GSTIN';
    END IF;
    IF LEFT(v_gstin, 2) <> v_state THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'gstin::GSTIN does not belong to the selected state';
    END IF;
    IF EXISTS (SELECT 1 FROM suppliers WHERE gstin = v_gstin AND id <> v_id AND is_deleted = 0) THEN
      SIGNAL SQLSTATE '45409' SET MESSAGE_TEXT = 'gstin::Another supplier has this GSTIN';
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM suppliers WHERE supplier_name = v_name AND id <> v_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45409' SET MESSAGE_TEXT = 'name::A supplier with this name already exists';
  END IF;
  IF IFNULL(p_payment_terms_days, 0) < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'paymentTermsDays::Payment terms cannot be negative';
  END IF;

  START TRANSACTION;

  IF v_id = 0 THEN
    CALL sp_util_next_number('SUP', v_code);
    WHILE EXISTS (SELECT 1 FROM suppliers WHERE supplier_code = v_code AND is_deleted = 0) DO
      CALL sp_util_next_number('SUP', v_code);
    END WHILE;

    INSERT INTO suppliers (supplier_code, supplier_name, contact_person, mobile, email, address, state_code, gstin,
                           opening_balance, payment_terms_days, current_balance, status, created_by)
    VALUES (v_code, v_name, NULLIF(TRIM(p_contact_person), ''), p_mobile, NULLIF(TRIM(p_email), ''), TRIM(p_address), v_state, v_gstin,
            v_opening, IFNULL(p_payment_terms_days, 0), v_opening, IFNULL(p_status, 1), p_user_id);
    SET v_id = LAST_INSERT_ID();
  ELSE
    SELECT opening_balance INTO v_old_opening FROM suppliers WHERE id = v_id AND is_deleted = 0 FOR UPDATE;
    IF v_old_opening IS NULL THEN
      SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Supplier not found';
    END IF;

    UPDATE suppliers
       SET supplier_name = v_name, contact_person = NULLIF(TRIM(p_contact_person), ''), mobile = p_mobile,
           email = NULLIF(TRIM(p_email), ''), address = TRIM(p_address), state_code = v_state, gstin = v_gstin,
           opening_balance = v_opening, payment_terms_days = IFNULL(p_payment_terms_days, 0),
           current_balance = current_balance + (v_opening - v_old_opening),
           status = IFNULL(p_status, 1), updated_by = p_user_id, updated_at = NOW()
     WHERE id = v_id;
  END IF;

  COMMIT;

  SELECT v_id AS id, 'Supplier saved successfully' AS message;
END
