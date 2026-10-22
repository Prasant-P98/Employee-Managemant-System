const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const path = require('path');

const app = express();
app.use(express.json());
app.use(cors());
app.use(express.static(path.join(__dirname, 'public')));

// Database Connection Pool
const db = mysql.createPool({
  host: 'localhost',
  user: 'root',          // Replace with your MySQL username
  password: 'Mysql@123',  // Replace with your MySQL password
  database: 'ems_db',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

// --- REST API ENDPOINTS ---

// 1. Add Employee (Calls Stored Procedure)
app.post('/api/employees', async (req, res) => {
  try {
    const { first_name, last_name, email, phone, hire_date, designation, dept_id, role_id, salary, password } = req.body;
    await db.query(
      'CALL sp_add_employee(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [first_name, last_name, email, phone, hire_date, designation, dept_id, role_id, salary, password]
    );
    res.json({ success: true, message: 'Employee added successfully!' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 2. Attendance Clock In / Clock Out
app.post('/api/attendance/clock-in', async (req, res) => {
  try {
    const { employee_id } = req.body;
    await db.query('CALL sp_clock_in(?)', [employee_id]);
    res.json({ success: true, message: 'Clocked in successfully!' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/attendance/clock-out', async (req, res) => {
  try {
    const { employee_id } = req.body;
    await db.query('CALL sp_clock_out(?)', [employee_id]);
    res.json({ success: true, message: 'Clocked out successfully!' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 3. Generate Monthly Payroll
app.post('/api/payroll/generate', async (req, res) => {
  try {
    const { month, year } = req.body;
    await db.query('CALL sp_generate_payroll(?, ?)', [month, year]);
    res.json({ success: true, message: `Payroll generated for ${month}/${year}` });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 4. Fetch Payslips (From Reporting View)
app.get('/api/payroll/payslips', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM vw_monthly_payslips ORDER BY generated_date DESC');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 5. Fetch Attendance Analytics View
app.get('/api/attendance/report', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM vw_attendance_report');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}`);
});