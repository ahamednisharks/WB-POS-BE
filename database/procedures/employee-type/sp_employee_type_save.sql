-- sp_employee_type_save
-- Purpose : Insert (p_id = 0) or update an employee type.
-- Params  : p_id, p_type_name, p_description, p_can_login, p_status, p_user_id
-- Results : (1) id, message
-- Errors  : 45000 name required, 45404 not found, 45409 duplicate
CREATE PROCEDURE sp_employee_type_save(
  IN p_id          INT,
  IN p_type_name   VARCHAR(40),
  IN p_description VARCHAR(200),
  IN p_can_login   TINYINT,
  IN p_status      TINYINT,
  IN p_user_id     INT
)
BEGIN
  DECLARE v_id   INT DEFAULT IFNULL(p_id, 0);
  DECLARE v_name VARCHAR(40) DEFAULT TRIM(IFNULL(p_type_name, ''));

  IF v_name = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'name::Type name is required';
  END IF;
  IF EXISTS (SELECT 1 FROM employee_types WHERE type_name = v_name AND id <> v_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45409' SET MESSAGE_TEXT = 'name::This employee type already exists';
  END IF;

  IF v_id = 0 THEN
    INSERT INTO employee_types (type_name, description, can_login, status, created_by)
    VALUES (v_name, NULLIF(TRIM(p_description), ''), IFNULL(p_can_login, 0), IFNULL(p_status, 1), p_user_id);
    SET v_id = LAST_INSERT_ID();
  ELSE
    IF NOT EXISTS (SELECT 1 FROM employee_types WHERE id = v_id AND is_deleted = 0) THEN
      SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Employee type not found';
    END IF;
    UPDATE employee_types
       SET type_name = v_name, description = NULLIF(TRIM(p_description), ''), can_login = IFNULL(p_can_login, 0),
           status = IFNULL(p_status, 1), updated_by = p_user_id, updated_at = NOW()
     WHERE id = v_id;
  END IF;

  SELECT v_id AS id, 'Employee type saved successfully' AS message;
END
