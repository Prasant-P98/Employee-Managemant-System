-- ============================================================================
-- EMPLOYEE MANAGEMENT SYSTEM (EMS) - MYSQL WORKBENCH MINI PROJECT
-- ============================================================================

DROP DATABASE IF EXISTS ems_db;
CREATE DATABASE ems_db;
USE ems_db;

-- ----------------------------------------------------------------------------
-- STEP 1: DATABASE SCHEMA DEFINITION (TABLES & CONSTRAINTS)
-- ----------------------------------------------------------------------------

-- 1. Departments Table
CREATE TABLE departments (
    department_id INT AUTO_INCREMENT PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL UNIQUE,
    location VARCHAR(100) DEFAULT 'Main Campus'
);

-- 2. Roles & Permissions Table
CREATE TABLE user_roles (
    role_id INT AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE
);

-- 3. Employees Table
CREATE TABLE employees (
    employee_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone_number VARCHAR(20),
    hire_date DATE NOT NULL,
    designation VARCHAR(50) NOT NULL,
    department_id INT,
    role_id INT NOT NULL,
    base_salary DECIMAL(10, 2) NOT NULL CHECK (base_salary >= 0),
    status ENUM('ACTIVE', 'INACTIVE', 'TERMINATED') DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (department_id) REFERENCES departments(department_id) ON DELETE SET NULL,
	FOREIGN KEY (role_id) REFERENCES user_roles(role_id)
);

-- 4. User Passwords & Authentication Table
CREATE TABLE user_auth (
    employee_id INT PRIMARY KEY,
    password_hash VARCHAR(255) NOT NULL,
    last_login TIMESTAMP NULL,
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE
);

-- 5. Daily Attendance Table
CREATE TABLE attendance (
    attendance_id INT AUTO_INCREMENT PRIMARY KEY,
    employee_id INT NOT NULL,
    work_date DATE NOT NULL,
    time_in TIME,
    time_out TIME,
    hours_worked DECIMAL(4,2) DEFAULT 0.00,
    overtime_hours DECIMAL(4,2) DEFAULT 0.00,
    status ENUM('PRESENT', 'ABSENT', 'HALF_DAY', 'ON_LEAVE') DEFAULT 'PRESENT',
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
    UNIQUE KEY unique_daily_attendance (employee_id, work_date)
);

-- 6. Payroll & Payslips Table
CREATE TABLE payroll (
    payroll_id INT AUTO_INCREMENT PRIMARY KEY,
    employee_id INT NOT NULL,
    pay_period_month INT NOT NULL CHECK (pay_period_month BETWEEN 1 AND 12),
    pay_period_year INT NOT NULL,
    base_pay DECIMAL(10, 2) NOT NULL,
    overtime_pay DECIMAL(10, 2) DEFAULT 0.00,
    bonuses DECIMAL(10, 2) DEFAULT 0.00,
    deductions DECIMAL(10, 2) DEFAULT 0.00,
    net_salary DECIMAL(10, 2) NOT NULL,
    generated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
    UNIQUE KEY unique_monthly_payroll (employee_id, pay_period_month, pay_period_year)
);

-- 7. Salary Advances Table
CREATE TABLE salary_advances (
    advance_id INT AUTO_INCREMENT PRIMARY KEY,
    employee_id INT NOT NULL,
    amount_requested DECIMAL(10, 2) NOT NULL CHECK (amount_requested > 0),
    request_date DATE NOT NULL,
    status ENUM('PENDING', 'APPROVED', 'REJECTED') DEFAULT 'PENDING',
    approval_date DATE NULL,
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE
);

-- 8. Performance Evaluations Table
CREATE TABLE performance_reviews (
    review_id INT AUTO_INCREMENT PRIMARY KEY,
    employee_id INT NOT NULL,
    reviewer_id INT NOT NULL,
    review_date DATE NOT NULL,
    rating INT CHECK (rating BETWEEN 1 AND 5),
    feedback TEXT,
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
    FOREIGN KEY (reviewer_id) REFERENCES employees(employee_id)
);

-- 9. Audit Logging Table
CREATE TABLE audit_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    action_performed VARCHAR(100) NOT NULL,
    employee_id INT,
    performed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details TEXT
);

-- ----------------------------------------------------------------------------
-- STEP 2: PROCEDURAL STORED FUNCTIONS & PROCEDURES
-- ----------------------------------------------------------------------------

DELIMITER //

-- Function: Calculate working hours between clock-in and clock-out
CREATE FUNCTION sp_calc_hours(in_time TIME, out_time TIME) 
RETURNS DECIMAL(4,2)
DETERMINISTIC
BEGIN
    DECLARE total_sec INT;
    IF in_time IS NULL OR out_time IS NULL THEN
        RETURN 0.00;
    END IF;
    SET total_sec = TIMESTAMPDIFF(SECOND, in_time, out_time);
    IF total_sec < 0 THEN
        RETURN 0.00;
    END IF;
    RETURN ROUND(total_sec / 3600.0, 2);
END //

-- 1. EMPLOYEE MANAGEMENT PROCEDURES
CREATE PROCEDURE sp_add_employee(
    IN p_first VARCHAR(50),
    IN p_last VARCHAR(50),
    IN p_email VARCHAR(100),
    IN p_phone VARCHAR(20),
    IN p_hire DATE,
    IN p_designation VARCHAR(50),
    IN p_dept_id INT,
    IN p_role_id INT,
    IN p_salary DECIMAL(10,2),
    IN p_password VARCHAR(255)
)
BEGIN
    DECLARE new_emp_id INT;
    INSERT INTO employees (first_name, last_name, email, phone_number, hire_date, designation, department_id, role_id, base_salary)
    VALUES (p_first, p_last, p_email, p_phone, p_hire, p_designation, p_dept_id, p_role_id, p_salary);
    
    SET new_emp_id = LAST_INSERT_ID();
    
    INSERT INTO user_auth (employee_id, password_hash)
    VALUES (new_emp_id, SHA2(p_password, 256));
    
    INSERT INTO audit_logs (action_performed, employee_id, details)
    VALUES ('ADD_EMPLOYEE', new_emp_id, CONCAT('Employee created: ', p_first, ' ', p_last));
END //

CREATE PROCEDURE sp_update_employee(
    IN p_emp_id INT,
    IN p_phone VARCHAR(20),
    IN p_designation VARCHAR(50),
    IN p_dept_id INT,
    IN p_salary DECIMAL(10,2)
)
BEGIN
    UPDATE employees 
    SET phone_number = p_phone,
        designation = p_designation,
        department_id = p_dept_id,
        base_salary = p_salary
    WHERE employee_id = p_emp_id;

    INSERT INTO audit_logs (action_performed, employee_id, details)
    VALUES ('UPDATE_EMPLOYEE', p_emp_id, 'Updated contact, role, or compensation details.');
END //

-- 2. ATTENDANCE MANAGEMENT PROCEDURES
CREATE PROCEDURE sp_clock_in(IN p_emp_id INT)
BEGIN
    INSERT INTO attendance (employee_id, work_date, time_in, status)
    VALUES (p_emp_id, CURDATE(), CURTIME(), 'PRESENT')
    ON DUPLICATE KEY UPDATE time_in = CURTIME(), status = 'PRESENT';
END //

CREATE PROCEDURE sp_clock_out(IN p_emp_id INT)
BEGIN
    DECLARE v_in TIME;
    DECLARE v_hours DECIMAL(4,2);
    DECLARE v_overtime DECIMAL(4,2) DEFAULT 0.00;

    SELECT time_in INTO v_in 
    FROM attendance 
    WHERE employee_id = p_emp_id AND work_date = CURDATE();

    IF v_in IS NOT NULL THEN
        SET v_hours = sp_calc_hours(v_in, CURTIME());
        IF v_hours > 8.00 THEN
            SET v_overtime = v_hours - 8.00;
        END IF;

        UPDATE attendance 
        SET time_out = CURTIME(),
            hours_worked = v_hours,
            overtime_hours = v_overtime
        WHERE employee_id = p_emp_id AND work_date = CURDATE();
    END IF;
END //

-- 3. PAYROLL MANAGEMENT PROCEDURE
CREATE PROCEDURE sp_generate_payroll(
    IN p_month INT,
    IN p_year INT
)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_emp_id INT;
    DECLARE v_base DECIMAL(10,2);
    DECLARE v_overtime_hrs DECIMAL(10,2);
    DECLARE v_ot_pay DECIMAL(10,2);
    DECLARE v_advance_deduct DECIMAL(10,2);
    DECLARE v_net DECIMAL(10,2);

    DECLARE emp_cursor CURSOR FOR 
        SELECT employee_id, base_salary FROM employees WHERE status = 'ACTIVE';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN emp_cursor;

    read_loop: LOOP
        FETCH emp_cursor INTO v_emp_id, v_base;
        IF done THEN
            LEAVE read_loop;
        END IF;

        -- Calculate overtime earnings (Overtime rate = 1.5x hourly rate based on 160h work month)
        SELECT IFNULL(SUM(overtime_hours), 0) INTO v_overtime_hrs
        FROM attendance
        WHERE employee_id = v_emp_id 
          AND MONTH(work_date) = p_month 
          AND YEAR(work_date) = p_year;

        SET v_ot_pay = ROUND(v_overtime_hrs * (v_base / 160.0) * 1.5, 2);

        -- Calculate approved advance deductions
        SELECT IFNULL(SUM(amount_requested), 0) INTO v_advance_deduct
        FROM salary_advances
        WHERE employee_id = v_emp_id 
          AND status = 'APPROVED' 
          AND MONTH(approval_date) = p_month 
          AND YEAR(approval_date) = p_year;

        SET v_net = v_base + v_ot_pay - v_advance_deduct;

        INSERT INTO payroll (employee_id, pay_period_month, pay_period_year, base_pay, overtime_pay, deductions, net_salary)
        VALUES (v_emp_id, p_month, p_year, v_base, v_ot_pay, v_advance_deduct, v_net)
        ON DUPLICATE KEY UPDATE 
            base_pay = VALUES(base_pay),
            overtime_pay = VALUES(overtime_pay),
            deductions = VALUES(deductions),
            net_salary = VALUES(net_salary);

    END LOOP;

    CLOSE emp_cursor;
END //

-- 4. PERFORMANCE EVALUATION PROCEDURE
drop procedure sp_record_performance_review;
CREATE PROCEDURE sp_record_performance_review(
    IN p_emp_id INT,
    IN p_reviewer_id INT,
    IN p_rating INT,
    IN p_feedback TEXT
)

BEGIN
    INSERT INTO performance_reviews (employee_id, reviewer_id, review_date, rating, feedback)
    VALUES (p_emp_id, p_reviewer_id, CURDATE(), p_rating, p_feedback);
    
    INSERT INTO audit_logs (action_performed, employee_id, details)
    VALUES ('PERFORMANCE_REVIEW', p_emp_id, CONCAT('Review added with rating: ', p_rating));
END //

DELIMITER ;

-- ----------------------------------------------------------------------------
-- STEP 3: AUTOMATED TRIGGERS FOR SECURITY & INTEGRITY
-- ----------------------------------------------------------------------------

DELIMITER //

-- Prevent soft/hard deletion of active employees with pending advances
CREATE TRIGGER trg_prevent_invalid_employee_delete
BEFORE DELETE ON employees
FOR EACH ROW
BEGIN
    DECLARE pending_count INT;
    SELECT COUNT(*) INTO pending_count 
    FROM salary_advances 
    WHERE employee_id = OLD.employee_id AND status = 'PENDING';

    IF pending_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Cannot delete employee with pending salary advance requests.';
    END IF;
END //

-- Automatically log salary updates
CREATE TRIGGER trg_log_salary_change
AFTER UPDATE ON employees
FOR EACH ROW
BEGIN
    IF OLD.base_salary <> NEW.base_salary THEN
        INSERT INTO audit_logs (action_performed, employee_id, details)
        VALUES (
            'SALARY_CHANGE', 
            NEW.employee_id, 
            CONCAT('Base salary updated from ', OLD.base_salary, ' to ', NEW.base_salary)
        );
    END IF;
END //

DELIMITER ;

-- ----------------------------------------------------------------------------
-- STEP 4: REPORTING VIEWS
-- ----------------------------------------------------------------------------

-- Monthly Attendance Analytics View
CREATE OR REPLACE VIEW vw_attendance_report AS
SELECT 
    e.employee_id,
    CONCAT(e.first_name, ' ', e.last_name) AS full_name,
    d.department_name,
    COUNT(a.attendance_id) AS days_present,
    SUM(a.hours_worked) AS total_hours_worked,
    SUM(a.overtime_hours) AS total_overtime_hours
FROM employees e
LEFT JOIN departments d ON e.department_id = d.department_id
LEFT JOIN attendance a ON e.employee_id = a.employee_id
GROUP BY e.employee_id, full_name, d.department_name;

-- Comprehensive Payslip Overview View
CREATE OR REPLACE VIEW vw_monthly_payslips AS
SELECT 
    p.payroll_id,
    e.employee_id,
    CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
    e.designation,
    d.department_name,
    p.pay_period_month,
    p.pay_period_year,
    p.base_pay,
    p.overtime_pay,
    p.deductions,
    p.net_salary,
    p.generated_date
FROM payroll p
JOIN employees e ON p.employee_id = e.employee_id
LEFT JOIN departments d ON e.department_id = d.department_id;

-- Performance Review Analytics View
CREATE OR REPLACE VIEW vw_performance_summary AS
SELECT 
    e.employee_id,
    CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
    d.department_name,
    ROUND(AVG(pr.rating), 2) AS average_rating,
    COUNT(pr.review_id) AS total_reviews_conducted
FROM employees e
LEFT JOIN departments d ON e.department_id = d.department_id
LEFT JOIN performance_reviews pr ON e.employee_id = pr.employee_id
GROUP BY e.employee_id, employee_name, d.department_name;




-- initial Data
-- Insert Roles
INSERT INTO user_roles (role_name) VALUES ('HR Manager'), ('Software Engineer'), ('Team Lead');


-- Insert Departments
INSERT INTO departments (department_name, location) VALUES ('Engineering', 'Building A'), ('Human Resources', 'Building B');

-- Insert Initial Staff via Stored Procedure
CALL sp_add_employee('Prasanto', 'Pradhan', 'prasanto@company.com', '9876543210', '2025-01-15', 'Senior Engineer', 1, 3, 85000.00, 'SecurePass123');
CALL sp_add_employee('Ananya', 'Rao', 'ananya@company.com', '9123456789', '2025-02-01', 'HR Lead', 2, 1, 75000.00, 'AdminPass123');




-- Execute Business Logic & Workflows
-- 1. Simulate Clock-In and Clock-Out
CALL sp_clock_in(1);
-- Simulate 9.5 hours of work (1.5 hours overtime)
UPDATE attendance SET time_out = ADDTIME(time_in, '09:30:00') WHERE employee_id = 1 AND work_date = CURDATE();
CALL sp_clock_out(1);

-- 2. Request and Approve Salary Advance
INSERT INTO salary_advances (employee_id, amount_requested, request_date, status, approval_date) 
VALUES (1, 5000.00, CURDATE(), 'APPROVED', CURDATE());

-- 3. Calculate Monthly Payroll
CALL sp_generate_payroll(MONTH(CURDATE()), YEAR(CURDATE()));

-- 4. Record Performance Evaluation
CALL sp_record_performance_review(1, 2, 5, 'Exceeded performance expectations across all core deliverables.');




-- Verify Results via Analytical Views

-- Check Generated Payslips
SELECT * FROM vw_monthly_payslips;

-- Check Attendance Aggregations
SELECT * FROM vw_attendance_report;

-- Check Performance Summary
SELECT * FROM vw_performance_summary;

-- Check System Audit Logs
SELECT * FROM audit_logs;



SELECT department_id FROM departments;

SELECT role_id FROM user_roles;



