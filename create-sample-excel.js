const fs = require('fs');
const path = require('path');
const xlsx = require('xlsx');

function createSampleExcel() {
  const filePath = path.join(__dirname, 'public', 'sample_students.xlsx');
  console.log(`Generating sample Excel file at: ${filePath}`);

  const sampleData = [
    { 'User ID': '1001', 'Name': 'John Doe', 'Card Number': 'RFID_1001', 'Batch ID': 'CS_BATCH_A' },
    { 'User ID': '1002', 'Name': 'Jane Smith', 'Card Number': 'RFID_1002', 'Batch ID': 'CS_BATCH_A' },
    { 'User ID': '1003', 'Name': 'Alice Johnson', 'Card Number': 'RFID_1003', 'Batch ID': 'CS_BATCH_A' },
    { 'User ID': '1004', 'Name': 'Bob Brown', 'Card Number': 'RFID_1004', 'Batch ID': 'CS_BATCH_A' }
  ];

  const workbook = xlsx.utils.book_new();
  const worksheet = xlsx.utils.json_to_sheet(sampleData);
  xlsx.utils.book_append_sheet(workbook, worksheet, 'Students');
  
  // Write file to disk
  xlsx.writeFile(workbook, filePath);
  console.log('Sample Excel file generated successfully.');
}

createSampleExcel();
