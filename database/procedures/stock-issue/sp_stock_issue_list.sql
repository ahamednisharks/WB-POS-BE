-- sp_stock_issue_list
-- Purpose : Paged stock issues with footer totals for the same filter.
-- Params  : p_from DATE, p_to DATE (issue_date range), p_reason (PRODUCTION|WASTAGE|EXPIRED|DAMAGED|OTHER|NULL = any line reason),
--           p_status (POSTED|CANCELLED|NULL), p_search (issue no, remarks, issued-by name, item name),
--           p_sort_by (issueNo|issueDate|issuedByName|itemCount|totalValue|status|createdAt), p_sort_dir, p_page, p_limit
-- Results : (1) rows, (2) total, (3) totals (posted_count, cancelled_count, total_value of POSTED rows)
-- Errors  : none
-- Note    : the temporary table is declared with a primary key (the hosted DB runs sql_require_primary_key = ON,
--           which refuses CREATE TABLE ... AS SELECT).
CREATE PROCEDURE sp_stock_issue_list(
  IN p_from     DATE,
  IN p_to       DATE,
  IN p_reason   VARCHAR(10),
  IN p_status   VARCHAR(10),
  IN p_search   VARCHAR(100),
  IN p_sort_by  VARCHAR(30),
  IN p_sort_dir VARCHAR(4),
  IN p_page     INT,
  IN p_limit    INT
)
BEGIN
  DECLARE v_limit  INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 10), 1), 1000);
  DECLARE v_offset INT DEFAULT (GREATEST(IFNULL(p_page, 1), 1) - 1) * v_limit;
  DECLARE v_reason VARCHAR(10) DEFAULT NULLIF(TRIM(IFNULL(p_reason, '')), '');
  DECLARE v_status VARCHAR(10) DEFAULT NULLIF(TRIM(IFNULL(p_status, '')), '');
  DECLARE v_search VARCHAR(100) DEFAULT NULLIF(TRIM(IFNULL(p_search, '')), '');

  DROP TEMPORARY TABLE IF EXISTS tmp_si_rows;
  CREATE TEMPORARY TABLE tmp_si_rows (
    id                INT UNSIGNED  NOT NULL PRIMARY KEY,
    issue_no          VARCHAR(20)   NOT NULL,
    issue_date        DATE          NOT NULL,
    remarks           VARCHAR(200)  NULL,
    item_count        INT           NOT NULL,
    total_value       DECIMAL(12,2) NOT NULL,
    status            VARCHAR(10)   NOT NULL,
    issued_by         INT UNSIGNED  NOT NULL,
    issued_by_name    VARCHAR(100)  NULL,
    items_summary     TEXT          NULL,
    reasons           VARCHAR(80)   NULL,
    cancel_reason     VARCHAR(200)  NULL,
    cancelled_at      DATETIME      NULL,
    cancelled_by_name VARCHAR(100)  NULL,
    is_editable       TINYINT       NOT NULL,
    created_at        DATETIME      NOT NULL,
    updated_at        DATETIME      NOT NULL
  );

  INSERT INTO tmp_si_rows (id, issue_no, issue_date, remarks, item_count, total_value, status, issued_by, issued_by_name,
                           items_summary, reasons, cancel_reason, cancelled_at, cancelled_by_name, is_editable,
                           created_at, updated_at)
  SELECT si.id, si.issue_no, si.issue_date, si.remarks, si.item_count, si.total_value,
         si.issue_status, si.issued_by,
         COALESCE(e.full_name, IF(u.employee_id IS NULL AND u.role = 'ADMIN', 'Administrator', u.username)),
         (SELECT GROUP_CONCAT(CONCAT(i.item_name, ' x ', TRIM(TRAILING '.' FROM TRIM(TRAILING '0' FROM sii.qty)))
                              ORDER BY sii.line_no SEPARATOR ', ')
            FROM stock_issue_items sii JOIN items i ON i.id = sii.item_id
           WHERE sii.si_id = si.id),
         (SELECT GROUP_CONCAT(DISTINCT sii.reason ORDER BY sii.reason SEPARATOR ',')
            FROM stock_issue_items sii WHERE sii.si_id = si.id),
         si.cancel_reason, si.cancelled_at,
         COALESCE(ce.full_name, IF(cu.employee_id IS NULL AND cu.role = 'ADMIN', 'Administrator', cu.username)),
         IF(si.issue_status = 'POSTED' AND DATE(si.created_at) = CURDATE(), 1, 0),
         si.created_at, IFNULL(si.updated_at, si.created_at)
    FROM stock_issues si
    JOIN users u            ON u.id = si.issued_by
    LEFT JOIN employees e   ON e.id = u.employee_id
    LEFT JOIN users cu      ON cu.id = si.cancelled_by
    LEFT JOIN employees ce  ON ce.id = cu.employee_id
   WHERE (p_from IS NULL OR si.issue_date >= p_from)
     AND (p_to IS NULL OR si.issue_date <= p_to)
     AND (v_status IS NULL OR si.issue_status = v_status)
     AND (v_reason IS NULL OR EXISTS (SELECT 1 FROM stock_issue_items x WHERE x.si_id = si.id AND x.reason = v_reason))
     AND (v_search IS NULL
          OR si.issue_no LIKE CONCAT('%', v_search, '%')
          OR si.remarks LIKE CONCAT('%', v_search, '%')
          OR COALESCE(e.full_name, u.username) LIKE CONCAT('%', v_search, '%')
          OR EXISTS (SELECT 1 FROM stock_issue_items x JOIN items xi ON xi.id = x.item_id
                      WHERE x.si_id = si.id AND xi.item_name LIKE CONCAT('%', v_search, '%')));

  SELECT *
    FROM tmp_si_rows r
   ORDER BY
     CASE WHEN p_sort_by = 'issueNo'      AND p_sort_dir = 'asc'  THEN r.issue_no END ASC,
     CASE WHEN p_sort_by = 'issueNo'      AND p_sort_dir = 'desc' THEN r.issue_no END DESC,
     CASE WHEN p_sort_by = 'issueDate'    AND p_sort_dir = 'asc'  THEN r.issue_date END ASC,
     CASE WHEN p_sort_by = 'issueDate'    AND p_sort_dir = 'desc' THEN r.issue_date END DESC,
     CASE WHEN p_sort_by = 'issuedByName' AND p_sort_dir = 'asc'  THEN r.issued_by_name END ASC,
     CASE WHEN p_sort_by = 'issuedByName' AND p_sort_dir = 'desc' THEN r.issued_by_name END DESC,
     CASE WHEN p_sort_by = 'itemCount'    AND p_sort_dir = 'asc'  THEN r.item_count END ASC,
     CASE WHEN p_sort_by = 'itemCount'    AND p_sort_dir = 'desc' THEN r.item_count END DESC,
     CASE WHEN p_sort_by = 'totalValue'   AND p_sort_dir = 'asc'  THEN r.total_value END ASC,
     CASE WHEN p_sort_by = 'totalValue'   AND p_sort_dir = 'desc' THEN r.total_value END DESC,
     CASE WHEN p_sort_by = 'status'       AND p_sort_dir = 'asc'  THEN r.status END ASC,
     CASE WHEN p_sort_by = 'status'       AND p_sort_dir = 'desc' THEN r.status END DESC,
     CASE WHEN p_sort_by = 'createdAt'    AND p_sort_dir = 'asc'  THEN r.id END ASC,
     r.id DESC
   LIMIT v_limit OFFSET v_offset;

  SELECT COUNT(*) AS total FROM tmp_si_rows;

  SELECT IFNULL(SUM(status = 'POSTED'), 0) AS posted_count,
         IFNULL(SUM(status = 'CANCELLED'), 0) AS cancelled_count,
         IFNULL(SUM(IF(status = 'POSTED', total_value, 0)), 0) AS total_value
    FROM tmp_si_rows;

  DROP TEMPORARY TABLE IF EXISTS tmp_si_rows;
END
