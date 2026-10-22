const API_BASE = 'http://localhost:3000/api';

// Add Employee Form Handler
document.getElementById('addEmpForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  
  const payload = {
    first_name: document.getElementById('first_name').value,
    last_name: document.getElementById('last_name').value,
    email: document.getElementById('email').value,
    phone: document.getElementById('phone').value,
    hire_date: document.getElementById('hire_date').value,
    designation: document.getElementById('designation').value,
    // Converts text dropdown options into clean database integers
    dept_id: parseInt(document.getElementById('dept_id').value, 10),
    role_id: parseInt(document.getElementById('role_id').value, 10),
    // Converts salary text into a floating point decimal structure
    salary: parseFloat(document.getElementById('salary').value),
    password: document.getElementById('password').value
  };

  try {
    const res = await fetch(`${API_BASE}/employees`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const data = await res.json();
    alert(data.message || data.error || 'Operation executed.');
    if (data.success) document.getElementById('addEmpForm').reset();
  } catch (err) {
    console.error(err);
    alert('Failed to connect to the backend server.');
  }
});

// Clock In & Clock Out Functions
async function clockIn() {
  const empId = document.getElementById('clockEmpId').value;
  if (!empId) return alert('Enter Employee ID');
  try {
    const res = await fetch(`${API_BASE}/attendance/clock-in`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ employee_id: parseInt(empId, 10) })
    });
    const data = await res.json();
    alert(data.message || data.error);
  } catch (err) {
    console.error(err);
    alert('Error connecting to attendance service.');
  }
}

async function clockOut() {
  const empId = document.getElementById('clockEmpId').value;
  if (!empId) return alert('Enter Employee ID');
  try {
    const res = await fetch(`${API_BASE}/attendance/clock-out`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ employee_id: parseInt(empId, 10) })
    });
    const data = await res.json();
    alert(data.message || data.error);
  } catch (err) {
    console.error(err);
    alert('Error connecting to attendance service.');
  }
}

// Generate Payroll
async function generatePayroll() {
  const month = document.getElementById('payMonth').value;
  const year = document.getElementById('payYear').value;
  if (!month || !year) return alert('Enter Month and Year');
  try {
    const res = await fetch(`${API_BASE}/payroll/generate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        month: parseInt(month, 10), 
        year: parseInt(year, 10) 
      })
    });
    const data = await res.json();
    alert(data.message || data.error);
    loadPayslips();
  } catch (err) {
    console.error(err);
    alert('Error processing payroll execution pipeline.');
  }
}

// Load Reporting Data Views
async function loadPayslips() {
  try {
    const res = await fetch(`${API_BASE}/payroll/payslips`);
    const data = await res.json();
    const tbody = document.getElementById('payslipsTable');
    if (!data || data.error) {
      tbody.innerHTML = `<tr><td colspan="6" class="text-center text-danger">${data.error || 'Failed to load data'}</td></tr>`;
      return;
    }
    tbody.innerHTML = data.map(row => `
      <tr>
        <td>${row.employee_id}</td>
        <td>${row.employee_name || 'N/A'}</td>
        <td>${row.pay_period_month}/${row.pay_period_year}</td>
        <td>$${parseFloat(row.base_pay).toFixed(2)}</td>
        <td>$${parseFloat(row.overtime_pay).toFixed(2)}</td>
        <td><strong>$${parseFloat(row.net_salary).toFixed(2)}</strong></td>
      </tr>
    `).join('');
  } catch (err) {
    console.error(err);
  }
}

async function loadAttendance() {
  try {
    const res = await fetch(`${API_BASE}/attendance/report`);
    const data = await res.json();
    const tbody = document.getElementById('attendanceTable');
    if (!data || data.error) {
      tbody.innerHTML = `<tr><td colspan="5" class="text-center text-danger">${data.error || 'Failed to load data'}</td></tr>`;
      return;
    }
    tbody.innerHTML = data.map(row => `
      <tr>
        <td>${row.employee_id}</td>
        <td>${row.full_name || 'N/A'}</td>
        <td>${row.days_present}</td>
        <td>${row.total_hours_worked || 0} hrs</td>
        <td>${row.total_overtime_hours || 0} hrs</td>
      </tr>
    `).join('');
  } catch (err) {
    console.error(err);
  }
}
