-- sp_stock_summary
-- Purpose : Stock register of every stock-tracked item (RAW / BOTH, active) for a period, computed from stock_ledger:
--           opening (before p_from) + purchased + adjusted - used - wastage - sold = closing.
--           With p_from / p_to NULL the figures are cumulative (opening 0, closing = current stock).
--           Used = ISSUE lines with reason PRODUCTION; wastage = ISSUE lines with any other reason.
-- Params  : p_from DATE, p_to DATE, p_category_id, p_type (RAW|BOTH|NULL = both), p_low_only (1 = at/below min stock),
--           p_search (name, code, category),
--           p_sort_by (code|name|categoryName|opening|purchased|used|wastage|closing|currentStock|minStock|purchasePrice|stockValue),
--           p_sort_dir, p_page, p_limit
-- Results : (1) rows, (2) total, (3) totals (item_count, low_count, purchased, used, wastage, stock_value)
-- Errors  : 45000 from after to
-- Note    : the temporary table is declared with a primary key (the hosted DB runs sql_require_primary_key = ON,
--           which refuses CREATE TABLE ... AS SELECT).
CREATE PROCEDURE sp_stock_summary(
  IN p_from        DATE,
  IN p_to          DATE,
  IN p_category_id INT,
  IN p_type        VARCHAR(4),
  IN p_low_only    TINYINT,
  IN p_search      VARCHAR(100),
  IN p_sort_by     VARCHAR(30),
  IN p_sort_dir    VARCHAR(4),
  IN p_page        INT,
  IN p_limit       INT
)
BEGIN
  DECLARE v_limit   INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 10), 1), 1000);
  DECLARE v_offset  INT DEFAULT (GREATEST(IFNULL(p_page, 1), 1) - 1) * v_limit;
  DECLARE v_to_excl DATETIME DEFAULT IF(p_to IS NULL, NULL, p_to + INTERVAL 1 DAY);
  DECLARE v_type    VARCHAR(4) DEFAULT NULLIF(TRIM(IFNULL(p_type, '')), '');
  DECLARE v_search  VARCHAR(100) DEFAULT NULLIF(TRIM(IFNULL(p_search, '')), '');

  IF p_from IS NOT NULL AND p_to IS NOT NULL AND p_to < p_from THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'to::To date cannot be before From date';
  END IF;

  DROP TEMPORARY TABLE IF EXISTS tmp_stock_rows;
  CREATE TEMPORARY TABLE tmp_stock_rows (
    id             INT UNSIGNED  NOT NULL PRIMARY KEY,
    code           VARCHAR(20)   NOT NULL,
    name           VARCHAR(60)   NOT NULL,
    type           VARCHAR(4)    NOT NULL,
    category_id    INT UNSIGNED  NOT NULL,
    category_name  VARCHAR(50)   NOT NULL,
    unit_code      VARCHAR(5)    NOT NULL,
    allow_decimal  TINYINT(1)    NOT NULL,
    opening        DECIMAL(14,3) NOT NULL,
    purchased      DECIMAL(14,3) NOT NULL,
    used           DECIMAL(14,3) NOT NULL,
    wastage        DECIMAL(14,3) NOT NULL,
    sold           DECIMAL(14,3) NOT NULL,
    adjusted       DECIMAL(14,3) NOT NULL,
    closing        DECIMAL(14,3) NOT NULL,
    current_stock  DECIMAL(12,3) NOT NULL,
    min_stock      DECIMAL(12,3) NOT NULL,
    purchase_price DECIMAL(12,2) NOT NULL,
    stock_value    DECIMAL(14,2) NOT NULL,
    is_low         TINYINT       NOT NULL
  );

  INSERT INTO tmp_stock_rows (id, code, name, type, category_id, category_name, unit_code, allow_decimal,
                              opening, purchased, used, wastage, sold, adjusted, closing,
                              current_stock, min_stock, purchase_price, stock_value, is_low)
  SELECT i.id, i.item_code, i.item_name, i.item_type,
         i.category_id, c.category_name, u.short_code, u.allow_decimal,
         IFNULL(m.opening, 0),
         IFNULL(m.purchased, 0),
         IFNULL(m.used, 0),
         IFNULL(m.wastage, 0),
         IFNULL(m.sold, 0),
         IFNULL(m.adjusted, 0),
         IFNULL(m.opening, 0) + IFNULL(m.purchased, 0) + IFNULL(m.adjusted, 0)
           - IFNULL(m.used, 0) - IFNULL(m.wastage, 0) - IFNULL(m.sold, 0),
         i.current_stock, i.min_stock, i.purchase_price,
         ROUND(i.current_stock * i.purchase_price, 2),
         IF(i.min_stock > 0 AND i.current_stock <= i.min_stock, 1, 0)
    FROM items i
    JOIN categories c ON c.id = i.category_id
    JOIN units u      ON u.id = i.unit_id
    LEFT JOIN (
      SELECT l.item_id,
             SUM(IF(p_from IS NOT NULL AND l.txn_date < p_from, l.qty_in - l.qty_out, 0)) AS opening,
             SUM(IF((p_from IS NULL OR l.txn_date >= p_from) AND l.txn_type IN ('PURCHASE', 'PE_EDIT'),
                    l.qty_in - l.qty_out, 0)) AS purchased,
             SUM(IF((p_from IS NULL OR l.txn_date >= p_from) AND l.txn_type IN ('ISSUE', 'ISSUE_CANCEL')
                    AND IFNULL(sii.reason, 'PRODUCTION') = 'PRODUCTION', l.qty_out - l.qty_in, 0)) AS used,
             SUM(IF((p_from IS NULL OR l.txn_date >= p_from) AND l.txn_type IN ('ISSUE', 'ISSUE_CANCEL')
                    AND IFNULL(sii.reason, 'PRODUCTION') <> 'PRODUCTION', l.qty_out - l.qty_in, 0)) AS wastage,
             SUM(IF((p_from IS NULL OR l.txn_date >= p_from) AND l.txn_type IN ('SALE', 'SALE_CANCEL'),
                    l.qty_out - l.qty_in, 0)) AS sold,
             SUM(IF((p_from IS NULL OR l.txn_date >= p_from) AND l.txn_type IN ('OPENING', 'ADJUST', 'PRODUCTION'),
                    l.qty_in - l.qty_out, 0)) AS adjusted
        FROM stock_ledger l
        LEFT JOIN stock_issue_items sii
               ON l.ref_table = 'stock_issues' AND sii.si_id = l.ref_id AND sii.item_id = l.item_id
       WHERE v_to_excl IS NULL OR l.txn_date < v_to_excl
       GROUP BY l.item_id
    ) m ON m.item_id = i.id
   WHERE i.is_deleted = 0 AND i.status = 1 AND i.item_type <> 'SALE'
     AND (v_type IS NULL OR i.item_type = v_type)
     AND (p_category_id IS NULL OR i.category_id = p_category_id)
     AND (IFNULL(p_low_only, 0) = 0 OR (i.min_stock > 0 AND i.current_stock <= i.min_stock))
     AND (v_search IS NULL
          OR i.item_name LIKE CONCAT('%', v_search, '%')
          OR i.item_code LIKE CONCAT('%', v_search, '%')
          OR c.category_name LIKE CONCAT('%', v_search, '%'));

  SELECT *
    FROM tmp_stock_rows r
   ORDER BY
     CASE WHEN p_sort_by = 'code'          AND p_sort_dir = 'asc'  THEN r.code END ASC,
     CASE WHEN p_sort_by = 'code'          AND p_sort_dir = 'desc' THEN r.code END DESC,
     CASE WHEN p_sort_by = 'name'          AND p_sort_dir = 'desc' THEN r.name END DESC,
     CASE WHEN p_sort_by = 'categoryName'  AND p_sort_dir = 'asc'  THEN r.category_name END ASC,
     CASE WHEN p_sort_by = 'categoryName'  AND p_sort_dir = 'desc' THEN r.category_name END DESC,
     CASE WHEN p_sort_by = 'opening'       AND p_sort_dir = 'asc'  THEN r.opening END ASC,
     CASE WHEN p_sort_by = 'opening'       AND p_sort_dir = 'desc' THEN r.opening END DESC,
     CASE WHEN p_sort_by = 'purchased'     AND p_sort_dir = 'asc'  THEN r.purchased END ASC,
     CASE WHEN p_sort_by = 'purchased'     AND p_sort_dir = 'desc' THEN r.purchased END DESC,
     CASE WHEN p_sort_by = 'used'          AND p_sort_dir = 'asc'  THEN r.used END ASC,
     CASE WHEN p_sort_by = 'used'          AND p_sort_dir = 'desc' THEN r.used END DESC,
     CASE WHEN p_sort_by = 'wastage'       AND p_sort_dir = 'asc'  THEN r.wastage END ASC,
     CASE WHEN p_sort_by = 'wastage'       AND p_sort_dir = 'desc' THEN r.wastage END DESC,
     CASE WHEN p_sort_by = 'closing'       AND p_sort_dir = 'asc'  THEN r.closing END ASC,
     CASE WHEN p_sort_by = 'closing'       AND p_sort_dir = 'desc' THEN r.closing END DESC,
     CASE WHEN p_sort_by = 'currentStock'  AND p_sort_dir = 'asc'  THEN r.current_stock END ASC,
     CASE WHEN p_sort_by = 'currentStock'  AND p_sort_dir = 'desc' THEN r.current_stock END DESC,
     CASE WHEN p_sort_by = 'minStock'      AND p_sort_dir = 'asc'  THEN r.min_stock END ASC,
     CASE WHEN p_sort_by = 'minStock'      AND p_sort_dir = 'desc' THEN r.min_stock END DESC,
     CASE WHEN p_sort_by = 'purchasePrice' AND p_sort_dir = 'asc'  THEN r.purchase_price END ASC,
     CASE WHEN p_sort_by = 'purchasePrice' AND p_sort_dir = 'desc' THEN r.purchase_price END DESC,
     CASE WHEN p_sort_by = 'stockValue'    AND p_sort_dir = 'asc'  THEN r.stock_value END ASC,
     CASE WHEN p_sort_by = 'stockValue'    AND p_sort_dir = 'desc' THEN r.stock_value END DESC,
     r.name ASC
   LIMIT v_limit OFFSET v_offset;

  SELECT COUNT(*) AS total FROM tmp_stock_rows;

  SELECT COUNT(*) AS item_count, IFNULL(SUM(is_low), 0) AS low_count,
         IFNULL(SUM(purchased), 0) AS purchased, IFNULL(SUM(used), 0) AS used, IFNULL(SUM(wastage), 0) AS wastage,
         IFNULL(SUM(stock_value), 0) AS stock_value
    FROM tmp_stock_rows;

  DROP TEMPORARY TABLE IF EXISTS tmp_stock_rows;
END
