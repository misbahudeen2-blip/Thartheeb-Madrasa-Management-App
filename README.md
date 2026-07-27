# Tartheeb - Smart Madrasa & Biometric Attendance Management System

**Tartheeb** is a complete, multi-tenant Web Application and Real-Time Biometric Ingestion System designed for Madrasas, Schools, and Educational Institutions. It integrates directly with **eSSL / ZKTeco HTTP ADMS Biometric Devices** for automated attendance logging, student compliance reports, fee tracking, and teacher shift management.

---

## 🌟 Key Features

### 1. 📡 Real-Time Biometric Device Push (eSSL / ZKTeco)
- **ADMS HTTP Push Protocol**: Listens on `/iclock/cdata` and `/iclock/getrequest` for instant punch ingestion.
- **Auto Device Synchronization**: Real-time heartbeat tracking and automatic device online/offline detection.
- **Smart Grace Window**: Configurable grace periods (e.g. 5 mins) with automatic status tagging (**Present**, **Late**, **Early**, **Absent**).
- **Punctuality Scoring**: Calculates daily Punctuality Points (10 Points per on-time day) and compliance rates.

### 2. 👨‍🎓 Student & Batch Management
- **Multi-Tenant Architecture**: Supports Super Admin, Admin, Teacher, and Parent role-based access.
- **Batch Compliance Reports**: Detailed attendance, punctuality scoring out of 100, and fee status overview with instant PDF & CSV export.
- **Individual Student Report Cards**: Generate downloadable PDF and PNG student performance report cards.
- **Excel Bulk Import Engine**: Easily import students and teachers via `.xlsx` spreadsheets.

### 3. 📱 Mobile-First App UI
- **Custom UI Components**: In-app custom date pickers and batch selectors tailored for mobile screens (eliminates native OS dropdowns).
- **Date Navigation**: Rapid `◀` Previous / Next `▶` day navigation for quick attendance verification.
- **Amal & Prayer Checklist**: Parent and teacher tracking for daily prayers and habits.

### 4. 💳 Tuition & Fee Management
- Monthly tuition fee payment tracking (Paid/Unpaid) per student with custom receipt generation.
- Additional fee management for special events and materials.

---

## 🛠️ Technology Stack

- **Backend**: Node.js, Express.js
- **Database**: SQLite3 (`attendance.db`)
- **Frontend**: HTML5, Alpine.js, Vanilla CSS, Tailwind CSS (Utility classes)
- **Reporting & Export**: html2canvas, jsPDF, XLSX Parser
- **Biometric Integration**: eSSL ADMS / ZKTeco Push Ingestion Engine

---

## 🚀 Quick Start Guide

### 1. Requirements
- Node.js (v16.x or higher)
- npm (Node Package Manager)

### 2. Installation
Clone the repository and install dependencies:
```bash
git clone https://github.com/YOUR_USERNAME/essl_push_server.git
cd essl_push_server
npm install
```

### 3. Initialize Database
Initialize the SQLite database schema:
```bash
node init-db.js
```

### 4. Run the Server
Start the Node.js server:
```bash
node server.js
```
The server will run on:
- **Local PC**: `http://localhost:8081`
- **Local Network**: `http://<your_local_ip>:8081`

---

## 📟 Biometric Machine Setup (eSSL / ZKTeco)

To connect your biometric machine:
1. Open Machine **Menu ➔ Comm. ➔ Cloud Server Settings (ADMS)**.
2. Set **Server IP**: Local IP of the PC running this server (e.g., `192.168.1.8`).
3. Set **Server Port**: `8081`.
4. Set **Enable Domain Name**: `OFF`.
5. Save & Restart Machine.

---

## 📜 License
Developed for Tartheeb Madrasa Management System. All Rights Reserved.
