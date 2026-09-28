-- sp_unit_save
-- Purpose : Insert (p_id = 0) or update (p_id > 0) a unit.
-- Params  : p_id, p_unit_name, p_short_code, p_allow_decimal, p_status, p_user_id
-- Results : (1) id, message
-- Errors  : 45000 validation, 45404 not found, 45409 duplicate name / short code
CREATE PROCEDURE sp_unit_save(
  IN p_id            INT,
  IN p_unit_name     VARCHAR(30),
  IN p_short_code    VARCHAR(5),
  IN p_allow_decimal TINYINT,
  IN p_status        TINYINT,
  IN p_user_id       INT
)
BEGIN
  DECLARE v_id   INT DEFAULT IFNULL(p_id, 0);
  DECLARE v_name VARCHAR(30) DEFAULT TRIM(IFNULL(p_unit_name, ''));
  DECLARE v_code VARCHAR(5)  DEFAULT UPPER(TRIM(IFNULL(p_short_code, '')));

  IF v_name = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'name::Unit name is required';
  END IF;
  IF v_code = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'shortCode::Short code is required';
  END IF;
  IF EXISTS (SELECT 1 FROM units WHERE unit_name = v_name AND id <> v_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45409' SET MESSAGE_TEXT = 'name::A unit with this name already exists';
  END IF;
  IF EXISTS (SELECT 1 FROM units WHERE short_code = v_code AND id <> v_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45409' SET MESSAGE_TEXT = 'shortCode::This short code is already used';
  END IF;

  IF v_id = 0 THEN
    INSERT INTO units (unit_name, short_code, allow_decimal, status, created_by)
    VALUES (v_name, v_code, IFNULL(p_allow_decimal, 0), IFNULL(p_status, 1), p_user_id);
    SET v_id = LAST_INSERT_ID();
  ELSE
    IF NOT EXISTS (SELECT 1 FROM units WHERE id = v_id AND is_deleted = 0) THEN
      SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Unit not found';
    END IF;
    UPDATE units
       SET unit_name = v_name, short_code = v_code, allow_decimal = IFNULL(p_allow_decimal, 0),
           status = IFNULL(p_status, 1), updated_by = p_user_id, updated_at = NOW()
     WHERE id = v_id;
  END IF;

  SELECT v_id AS id, 'Unit saved successfully' AS message;
END
