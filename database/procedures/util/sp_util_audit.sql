-- sp_util_audit
-- Purpose : Writes one audit_log row (used by cancel / delete / price-change flows).
-- Params  : p_user_id, p_action, p_table, p_record_id, p_old JSON, p_new JSON
-- Results : none
-- Errors  : none
CREATE PROCEDURE sp_util_audit(
  IN p_user_id   INT,
  IN p_action    VARCHAR(40),
  IN p_table     VARCHAR(40),
  IN p_record_id INT,
  IN p_old       JSON,
  IN p_new       JSON
)
BEGIN
  INSERT INTO audit_log (user_id, action, table_name, record_id, old_json, new_json)
  VALUES (p_user_id, p_action, p_table, p_record_id, p_old, p_new);
END
