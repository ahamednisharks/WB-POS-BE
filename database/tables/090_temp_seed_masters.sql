-- ============================================================================================================
-- TEMPORARY SAMPLE DATA - for testing only. Delete this file before setting up the live database.
-- Adds sample units, categories and sale items so billing / pre-orders can be tried straight after a migrate.
-- Safe to run again (`npm run migrate temp_seed_masters`): only records that do not exist yet are added,
-- matched by unit code / category name / item name, so existing masters are never duplicated or changed.
-- Item codes continue after the highest existing ITM code; prices include GST; opening stock is 0.
-- ============================================================================================================

-- Units: KG, PCS (an existing "PSC" unit is reused), BOX
INSERT INTO units (unit_name, short_code, allow_decimal)
SELECT s.unit_name, s.short_code, s.allow_decimal
  FROM (SELECT 'Kilogram' AS unit_name, 'KG' AS short_code, 1 AS allow_decimal, 'KG' AS alt_code
        UNION ALL SELECT 'Pieces', 'PCS', 0, 'PSC'
        UNION ALL SELECT 'Box', 'BOX', 0, 'BOX') AS s
 WHERE NOT EXISTS (SELECT 1 FROM units u
                    WHERE u.is_deleted = 0
                      AND (u.short_code IN (s.short_code, s.alt_code) OR u.unit_name = s.unit_name));

-- Categories: Cakes, Sweets, Kaaram
INSERT INTO categories (category_name, display_order)
SELECT s.category_name, s.display_order
  FROM (SELECT 'Cakes' AS category_name, 1 AS display_order
        UNION ALL SELECT 'Sweets', 2
        UNION ALL SELECT 'Kaaram', 3) AS s
 WHERE NOT EXISTS (SELECT 1 FROM categories c WHERE c.is_deleted = 0 AND c.category_name = s.category_name);

-- Items
DROP TEMPORARY TABLE IF EXISTS tmp_seed_items;
CREATE TEMPORARY TABLE tmp_seed_items (
  seq            INT           NOT NULL PRIMARY KEY,
  item_name      VARCHAR(60)   NOT NULL,
  category_name  VARCHAR(50)   NOT NULL,
  unit_code      VARCHAR(5)    NOT NULL,
  selling_price  DECIMAL(12,2) NOT NULL,
  gst_pct        DECIMAL(5,2)  NOT NULL,
  hsn_code       VARCHAR(8)    NULL
);

INSERT INTO tmp_seed_items (seq, item_name, category_name, unit_code, selling_price, gst_pct, hsn_code) VALUES
  ( 1, 'Black Forest Cake',      'Cakes',  'KG',   600, 5, '1905'),
  ( 2, 'White Forest Cake',      'Cakes',  'KG',   650, 5, '1905'),
  ( 3, 'Butterscotch Cake',      'Cakes',  'KG',   600, 5, '1905'),
  ( 4, 'Chocolate Truffle Cake', 'Cakes',  'KG',   800, 5, '1905'),
  ( 5, 'Red Velvet Cake',        'Cakes',  'KG',   900, 5, '1905'),
  ( 6, 'Plum Cake',              'Cakes',  'PCS',  120, 5, '1905'),
  ( 7, 'Cup Cake',               'Cakes',  'PCS',   30, 5, '1905'),
  ( 8, 'Sweet Bun',              'Sweets', 'PCS',   15, 5, '1905'),
  ( 9, 'Cream Bun',              'Sweets', 'PCS',   25, 5, '1905'),
  (10, 'Coconut Bun',            'Sweets', 'PCS',   20, 5, '1905'),
  (11, 'Motichoor Laddu',        'Sweets', 'KG',   480, 5, '2106'),
  (12, 'Boondi Laddu',           'Sweets', 'KG',   400, 5, '2106'),
  (13, 'Rava Laddu',             'Sweets', 'PCS',   15, 5, '2106'),
  (14, 'Mysore Pak',             'Sweets', 'KG',   520, 5, '2106'),
  (15, 'Kaju Katli',             'Sweets', 'KG',  1100, 5, '2106'),
  (16, 'Assorted Sweets Box',    'Sweets', 'BOX',  350, 5, '2106'),
  (17, 'Laddu Gift Box',         'Sweets', 'BOX',  250, 5, '2106'),
  (18, 'Veg Puff',               'Kaaram', 'PCS',   25, 5, '1905'),
  (19, 'Egg Puff',               'Kaaram', 'PCS',   30, 5, '1905'),
  (20, 'Paneer Puff',            'Kaaram', 'PCS',   35, 5, '1905'),
  (21, 'Mixture',                'Kaaram', 'KG',   320, 5, '2106'),
  (22, 'Murukku',                'Kaaram', 'KG',   360, 5, '2106'),
  (23, 'Ribbon Pakoda',          'Kaaram', 'KG',   340, 5, '2106'),
  (24, 'Kara Sev',               'Kaaram', 'KG',   340, 5, '2106'),
  (25, 'Samosa',                 'Kaaram', 'PCS',   15, 5, '2106'),
  (26, 'Kaaram Box (Assorted)',  'Kaaram', 'BOX',  200, 5, '2106');

SET @seed_last_itm = (SELECT CAST(IFNULL(MAX(CAST(SUBSTRING(item_code, 4) AS UNSIGNED)), 0) AS UNSIGNED)
                        FROM items WHERE item_code REGEXP '^ITM[0-9]+$');

INSERT INTO items (item_code, item_name, item_type, category_id, unit_id, selling_price, gst_pct, price_includes_gst, hsn_code)
SELECT CONCAT('ITM', LPAD(CAST(@seed_last_itm + ROW_NUMBER() OVER (ORDER BY s.seq) AS UNSIGNED), 4, '0')),
       s.item_name, 'SALE', c.id,
       (SELECT u.id FROM units u
         WHERE u.is_deleted = 0 AND (u.short_code = s.unit_code OR (s.unit_code = 'PCS' AND u.short_code = 'PSC'))
         ORDER BY u.short_code = s.unit_code DESC, u.id
         LIMIT 1),
       s.selling_price, s.gst_pct, 1, s.hsn_code
  FROM tmp_seed_items s
  JOIN categories c ON c.category_name = s.category_name AND c.is_deleted = 0
 WHERE NOT EXISTS (SELECT 1 FROM items i WHERE i.is_deleted = 0 AND i.item_name = s.item_name)
 ORDER BY s.seq;

DROP TEMPORARY TABLE IF EXISTS tmp_seed_items;
