CREATE TABLE IF NOT EXISTS users (
  id               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  employee_id      INT UNSIGNED NULL COMMENT 'NULL only for the seed admin and cashier',
  username         VARCHAR(30)  NOT NULL,
  password_hash    VARCHAR(100) NOT NULL,
  role             ENUM('ADMIN','CASHIER') NOT NULL,
  status           TINYINT(1)   NOT NULL DEFAULT 1 COMMENT '1 active, 0 blocked',
  failed_attempts  INT          NOT NULL DEFAULT 0,
  locked_until     DATETIME     NULL,
  last_login_at    DATETIME     NULL,
  is_deleted       TINYINT(1)   NOT NULL DEFAULT 0,
  created_by       INT          NULL,
  created_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by       INT          NULL,
  updated_at       DATETIME     NULL,
  active_username  VARCHAR(30)  GENERATED ALWAYS AS (IF(is_deleted = 0, username, NULL)) VIRTUAL,
  active_employee  INT UNSIGNED GENERATED ALWAYS AS (IF(is_deleted = 0, employee_id, NULL)) VIRTUAL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_username (active_username),
  UNIQUE KEY uq_users_employee (active_employee),
  KEY ix_users_status (status),
  CONSTRAINT fk_users_employee FOREIGN KEY (employee_id) REFERENCES employees (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Seed super admin: admin / admin@123 (bcrypt, 10 rounds). Change the password after the first login.
INSERT IGNORE INTO users (id, employee_id, username, password_hash, role, status)
VALUES (1, NULL, 'admin', '$2b$10$L16u6z4SVp.XAOeejl1SDuooFG/fD2tyXrAP8IW7Ml5mQSb092.NO', 'ADMIN', 1);

-- Seed cashier: cashier / cashier@123 (bcrypt, 10 rounds). Skipped if a 'cashier' user exists, even a deleted one.
INSERT INTO users (employee_id, username, password_hash, role, status)
SELECT NULL, 'cashier', '$2b$10$XUNKh0YIRTJhQJuasUZad.KM/2I8fTd1qj0zdUcYPMpmu0QnqL9jS', 'CASHIER', 1
  FROM DUAL
 WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'cashier');
