-- sp_supplier_ledger
-- Purpose : Supplier account statement: balance brought forward, purchase entries (credit) and payments (debit)
--           with a running balance (amount payable to the supplier).
-- Params  : p_supplier_id, p_from DATE (NULL = from the beginning), p_to DATE (NULL = today)
-- Results : (1) header (supplier, opening_balance, balance_before, closing_balance, current_balance),
--           (2) rows (entry_date, doc_type PURCHASE|PAYMENT, doc_no, reference, credit, debit, balance)
-- Errors  : 45404 supplier not found
CREATE PROCEDURE sp_supplier_ledger(IN p_supplier_id INT, IN p_from DATE, IN p_to DATE)
BEGIN
  DECLARE v_opening  DECIMAL(12,2);
  DECLARE v_before   DECIMAL(12,2) DEFAULT 0;
  DECLARE v_period   DECIMAL(12,2) DEFAULT 0;
  DECLARE v_to       DATE DEFAULT IFNULL(p_to, CURDATE());

  SELECT opening_balance INTO v_opening FROM suppliers WHERE id = p_supplier_id AND is_deleted = 0;
  IF v_opening IS NULL THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Supplier not found';
  END IF;

  IF p_from IS NOT NULL THEN
    SELECT v_opening
           + IFNULL((SELECT SUM(grand_total) FROM purchase_entries
                      WHERE supplier_id = p_supplier_id AND is_deleted = 0 AND pe_date < p_from), 0)
           - IFNULL((SELECT SUM(amount) FROM supplier_payments
                      WHERE supplier_id = p_supplier_id AND payment_date < p_from), 0)
      INTO v_before;
  ELSE
    SET v_before = v_opening;
  END IF;

  SELECT IFNULL((SELECT SUM(grand_total) FROM purchase_entries
                  WHERE supplier_id = p_supplier_id AND is_deleted = 0
                    AND (p_from IS NULL OR pe_date >= p_from) AND pe_date <= v_to), 0)
       - IFNULL((SELECT SUM(amount) FROM supplier_payments
                  WHERE supplier_id = p_supplier_id
                    AND (p_from IS NULL OR payment_date >= p_from) AND payment_date <= v_to), 0)
    INTO v_period;

  SELECT s.id, s.supplier_code AS code, s.supplier_name AS name, st.state_name AS state, IFNULL(s.gstin, '') AS gstin,
         s.opening_balance, v_before AS balance_before, v_before + v_period AS closing_balance, s.current_balance,
         p_from AS from_date, v_to AS to_date
    FROM suppliers s JOIN states st ON st.state_code = s.state_code
   WHERE s.id = p_supplier_id;

  SELECT x.entry_date, x.doc_type, x.doc_no, x.reference, x.ref_id AS pe_id, x.credit, x.debit,
         v_before + SUM(x.credit - x.debit) OVER (ORDER BY x.entry_date, x.sort_key, x.row_id
                                                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS balance
    FROM (
      SELECT pe.pe_date AS entry_date, 'PURCHASE' AS doc_type, pe.pe_no AS doc_no,
             CONCAT('Invoice ', pe.supplier_invoice_no) AS reference, pe.id AS ref_id,
             pe.grand_total AS credit, 0 AS debit, 1 AS sort_key, pe.id AS row_id
        FROM purchase_entries pe
       WHERE pe.supplier_id = p_supplier_id AND pe.is_deleted = 0
         AND (p_from IS NULL OR pe.pe_date >= p_from) AND pe.pe_date <= v_to
      UNION ALL
      SELECT sp.payment_date, 'PAYMENT', pe.pe_no,
             CONCAT(sp.payment_mode, IF(sp.reference_no IS NULL, '', CONCAT(' ', sp.reference_no))), sp.pe_id,
             0, sp.amount, 2, sp.id
        FROM supplier_payments sp
        JOIN purchase_entries pe ON pe.id = sp.pe_id
       WHERE sp.supplier_id = p_supplier_id
         AND (p_from IS NULL OR sp.payment_date >= p_from) AND sp.payment_date <= v_to
    ) AS x
   ORDER BY x.entry_date, x.sort_key, x.row_id;
END
