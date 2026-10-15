-- sp_auth_set_theme
-- Purpose : Saves the colour theme the logged-in user picked (allowed values are checked in Node).
-- Params  : p_user_id, p_theme
-- Results : (1) id, theme, message
-- Errors  : 45000 missing theme, 45404 user not found
CREATE PROCEDURE sp_auth_set_theme(IN p_user_id INT, IN p_theme VARCHAR(20))
BEGIN
  IF IFNULL(TRIM(p_theme), '') = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Theme is required';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'User not found';
  END IF;

  UPDATE users SET theme = TRIM(p_theme) WHERE id = p_user_id;

  SELECT p_user_id AS id, TRIM(p_theme) AS theme, 'Theme saved' AS message;
END
