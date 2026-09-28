-- sp_util_health
-- Purpose : Liveness probe for /api/health.
-- Params  : none
-- Results : (1) ok, server_time, version
-- Errors  : none
CREATE PROCEDURE sp_util_health()
BEGIN
  SELECT 1 AS ok, NOW() AS server_time, VERSION() AS version;
END
