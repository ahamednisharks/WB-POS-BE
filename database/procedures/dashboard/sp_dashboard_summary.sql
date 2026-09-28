-- sp_dashboard_summary
-- Purpose : Admin dashboard for a date range (completed bills only unless stated).
-- Params  : p_from DATE (NULL = today), p_to DATE (NULL = p_from)
-- Results : (1) cards: from_date, to_date, total_sales, total_bills, avg_bill, cancelled_count, cancelled_amount
--           (2) payment split: mode, amount (net of nothing - what was collected on completed bills)
--           (3) sales by hour 7..23: hour, amount, bills (missing hours filled with 0)
--           (4) top 5 items / combos by amount: name, qty, amount
--           (5) last 10 completed bills
--           (6) low-stock items (stock-tracked, active, current_stock < min_stock)
-- Errors  : 45000 from after to
CREATE PROCEDURE sp_dashboard_summary(IN p_from DATE, IN p_to DATE)
BEGIN
  DECLARE v_from DATE DEFAULT IFNULL(p_from, CURDATE());
  DECLARE v_to   DATE DEFAULT IFNULL(p_to, IFNULL(p_from, CURDATE()));

  IF v_to < v_from THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'to::To date cannot be before From date';
  END IF;

  SELECT v_from AS from_date, v_to AS to_date,
         IFNULL(SUM(IF(b.bill_status = 'COMPLETED', b.grand_total, 0)), 0) AS total_sales,
         IFNULL(SUM(b.bill_status = 'COMPLETED'), 0) AS total_bills,
         IFNULL(ROUND(SUM(IF(b.bill_status = 'COMPLETED', b.grand_total, 0)) / NULLIF(SUM(b.bill_status = 'COMPLETED'), 0), 2), 0) AS avg_bill,
         IFNULL(SUM(b.bill_status = 'CANCELLED'), 0) AS cancelled_count,
         IFNULL(SUM(IF(b.bill_status = 'CANCELLED', b.grand_total, 0)), 0) AS cancelled_amount
    FROM bills b
   WHERE b.is_deleted = 0 AND b.bill_status IN ('COMPLETED', 'CANCELLED')
     AND b.bill_date >= v_from AND b.bill_date < v_to + INTERVAL 1 DAY;

  SELECT m.mode, IFNULL(SUM(bp.amount), 0) AS amount
    FROM (SELECT 'CASH' AS mode UNION ALL SELECT 'UPI' UNION ALL SELECT 'CARD') m
    LEFT JOIN bill_payments bp ON bp.payment_mode = m.mode
          AND bp.bill_id IN (SELECT b.id FROM bills b
                              WHERE b.is_deleted = 0 AND b.bill_status = 'COMPLETED'
                                AND b.bill_date >= v_from AND b.bill_date < v_to + INTERVAL 1 DAY)
   GROUP BY m.mode
   ORDER BY FIELD(m.mode, 'CASH', 'UPI', 'CARD');

  WITH RECURSIVE hours (hr) AS (
    SELECT 7 UNION ALL SELECT hr + 1 FROM hours WHERE hr < 23
  )
  SELECT h.hr AS hour, IFNULL(SUM(b.grand_total), 0) AS amount, COUNT(b.id) AS bills
    FROM hours h
    LEFT JOIN bills b ON HOUR(b.bill_date) = h.hr
          AND b.is_deleted = 0 AND b.bill_status = 'COMPLETED'
          AND b.bill_date >= v_from AND b.bill_date < v_to + INTERVAL 1 DAY
   GROUP BY h.hr
   ORDER BY h.hr;

  SELECT bi.item_name AS name, SUM(bi.qty) AS qty, SUM(bi.line_total) AS amount
    FROM bill_items bi
    JOIN bills b ON b.id = bi.bill_id
   WHERE b.is_deleted = 0 AND b.bill_status = 'COMPLETED'
     AND b.bill_date >= v_from AND b.bill_date < v_to + INTERVAL 1 DAY
   GROUP BY IFNULL(bi.item_id, -bi.combo_id), bi.item_name
   ORDER BY amount DESC
   LIMIT 5;

  SELECT b.id, b.bill_no, b.bill_date,
         COALESCE(e.full_name, IF(u.employee_id IS NULL, 'Administrator', u.username)) AS cashier_name,
         b.grand_total, b.payment_mode
    FROM bills b
    JOIN users u ON u.id = b.cashier_id
    LEFT JOIN employees e ON e.id = u.employee_id
   WHERE b.is_deleted = 0 AND b.bill_status = 'COMPLETED'
     AND b.bill_date >= v_from AND b.bill_date < v_to + INTERVAL 1 DAY
   ORDER BY b.bill_date DESC, b.id DESC
   LIMIT 10;

  SELECT i.id, i.item_code AS code, i.item_name AS name, i.item_type AS type, u.short_code AS unit_code,
         i.current_stock, i.min_stock
    FROM items i
    JOIN units u ON u.id = i.unit_id
   WHERE i.is_deleted = 0 AND i.status = 1 AND i.item_type <> 'SALE'
     AND i.min_stock > 0 AND i.current_stock < i.min_stock
   ORDER BY (i.current_stock / i.min_stock), i.item_name
   LIMIT 20;
END
