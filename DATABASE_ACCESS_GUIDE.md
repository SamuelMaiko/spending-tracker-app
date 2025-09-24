# Database Access Guide

This guide explains how to view and interact with the SQLite database from your development laptop when using an Android emulator or physical device.

## Table of Contents
1. [Database Location](#database-location)
2. [Accessing Database on Emulator](#accessing-database-on-emulator)
3. [Accessing Database on Physical Device](#accessing-database-on-physical-device)
4. [Database Schema](#database-schema)
5. [Transaction Categorization System](#transaction-categorization-system)
6. [Common Database Operations](#common-database-operations)

## Database Location

The SQLite database file is stored at:
- **File name**: `spending_tracker.db`
- **Android path**: `/data/data/com.example.spending_app/app_flutter/spending_tracker.db`
- **Local path**: Application Documents Directory (managed by Flutter)

## Accessing Database on Emulator

### Method 1: Using Android Studio Device File Explorer

1. **Open Android Studio**
2. **Start your emulator** and run the Flutter app
3. **Open Device File Explorer**: `View > Tool Windows > Device File Explorer`
4. **Navigate to**: `/data/data/com.example.spending_app/app_flutter/`
5. **Find**: `spending_tracker.db`
6. **Right-click** on the file and select **"Save As"** to download it to your laptop
7. **Open with SQLite browser** or any SQLite client

### Method 2: Using ADB Commands

```bash
# Connect to emulator
adb shell

# Navigate to app directory
cd /data/data/com.example.spending_app/app_flutter/

# List files to confirm database exists
ls -la

# Exit shell
exit

# Pull database to your laptop
adb pull /data/data/com.example.spending_app/app_flutter/spending_tracker.db ./spending_tracker.db
```

### Method 3: Using ADB with SQLite Commands

```bash
# Connect to emulator and open SQLite
adb shell "sqlite3 /data/data/com.example.spending_app/app_flutter/spending_tracker.db"

# Example queries
.tables
.schema transactions
SELECT * FROM transactions LIMIT 10;
SELECT * FROM categories;
```

## Accessing Database on Physical Device

**Note**: Physical devices require root access to access app databases directly.

### For Rooted Devices:
Follow the same ADB commands as emulator method.

### For Non-Rooted Devices:
You'll need to implement a debug feature in the app to export the database:

```dart
// Add this method to your app for debugging
Future<void> exportDatabase() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = File(p.join(dbFolder.path, 'spending_tracker.db'));
  
  final externalDir = await getExternalStorageDirectory();
  final exportPath = '${externalDir!.path}/spending_tracker_export.db';
  
  await file.copy(exportPath);
  print('Database exported to: $exportPath');
}
```

## Database Schema

### Tables Overview

```sql
-- Wallets: Money sources (M-Pesa, Bank accounts, etc.)
CREATE TABLE wallets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    transaction_sender_name TEXT NOT NULL,
    amount REAL DEFAULT 0.0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Categories: Broad spending groups
CREATE TABLE categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL
);

-- Category Items: Specific items within categories
CREATE TABLE category_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    category_id INTEGER NOT NULL,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
);

-- Transactions: Individual money movements
CREATE TABLE transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    wallet_id INTEGER NOT NULL,
    category_item_id INTEGER NULL,
    amount REAL NOT NULL,
    transaction_cost REAL DEFAULT 0.0,
    type TEXT NOT NULL, -- 'CREDIT', 'DEBIT', 'TRANSFER', 'WITHDRAW'
    description TEXT NULL,
    date DATETIME NOT NULL,
    status TEXT DEFAULT 'UNCATEGORIZED',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (wallet_id) REFERENCES wallets(id) ON DELETE CASCADE,
    FOREIGN KEY (category_item_id) REFERENCES category_items(id) ON DELETE SET NULL
);
```

### Default Data

The app creates default categories and items:

**Categories:**
- Transport, Food, Bills, Fees, Savings, Income, Shopping, Entertainment

**Sample Category Items:**
- Transport: Uber, Matatu, Boda Boda, Fuel, Parking
- Food: Restaurant, Groceries, Fast Food, Coffee, Delivery
- Income: Salary, Freelance, Business, Investment Returns

## Transaction Categorization System

### How Categorization Works

1. **Automatic Categorization**: 
   - Received money (CREDIT transactions) are automatically linked to the "Income" category
   - The system finds the first available item in the Income category (e.g., "Salary")

2. **Manual Categorization**:
   - Users can categorize transactions through the UI
   - Transactions can be linked to Category + Category Item
   - Or just to a Category (stored in description with special prefix)

3. **Category-Only Transactions**:
   - When a transaction is categorized to a category without a specific item
   - Stored as: `description = "[CATEGORY_ONLY:CategoryName] Original Description"`
   - Example: `"[CATEGORY_ONLY:Food] Sent from M-Pesa"`

### Database Relationships

```
Wallets (1) ←→ (Many) Transactions
Categories (1) ←→ (Many) CategoryItems
CategoryItems (1) ←→ (Many) Transactions
```

### Categorization Examples

**Example 1: Income Transaction (Auto-categorized)**
```sql
-- Received money automatically linked to Income
INSERT INTO transactions (
    wallet_id, category_item_id, amount, type, 
    description, date, status
) VALUES (
    1, 25, 5000.00, 'CREDIT', 
    'Received to M-Pesa', '2024-01-15', 'CATEGORIZED'
);
```

**Example 2: Manual Categorization with Item**
```sql
-- User categorizes expense to Transport > Uber
UPDATE transactions 
SET category_item_id = 1, status = 'CATEGORIZED'
WHERE id = 123;
```

**Example 3: Category-Only Categorization**
```sql
-- User categorizes to Food category only (no specific item)
UPDATE transactions 
SET description = '[CATEGORY_ONLY:Food] Sent from M-Pesa'
WHERE id = 124;
```

## Common Database Operations

### View All Transactions with Categories
```sql
SELECT 
    t.id,
    t.amount,
    t.type,
    t.description,
    t.date,
    w.name as wallet_name,
    c.name as category_name,
    ci.name as category_item_name
FROM transactions t
LEFT JOIN wallets w ON t.wallet_id = w.id
LEFT JOIN category_items ci ON t.category_item_id = ci.id
LEFT JOIN categories c ON ci.category_id = c.id
ORDER BY t.date DESC;
```

### View Uncategorized Transactions
```sql
SELECT * FROM transactions 
WHERE category_item_id IS NULL 
AND description NOT LIKE '[CATEGORY_ONLY:%'
ORDER BY date DESC;
```

### View Income Transactions
```sql
SELECT t.*, c.name as category_name, ci.name as item_name
FROM transactions t
LEFT JOIN category_items ci ON t.category_item_id = ci.id
LEFT JOIN categories c ON ci.category_id = c.id
WHERE t.type = 'CREDIT' OR c.name = 'Income'
ORDER BY t.date DESC;
```

### View Spending by Category
```sql
SELECT 
    c.name as category,
    SUM(t.amount) as total_spent,
    COUNT(t.id) as transaction_count
FROM transactions t
JOIN category_items ci ON t.category_item_id = ci.id
JOIN categories c ON ci.category_id = c.id
WHERE t.type = 'DEBIT'
GROUP BY c.id, c.name
ORDER BY total_spent DESC;
```

## Recommended SQLite Tools

1. **DB Browser for SQLite** (Free, Cross-platform)
   - Download: https://sqlitebrowser.org/
   - Great for viewing and editing SQLite databases

2. **SQLite Studio** (Free, Cross-platform)
   - Download: https://sqlitestudio.pl/
   - Advanced features for database management

3. **DBeaver** (Free, Cross-platform)
   - Download: https://dbeaver.io/
   - Universal database tool with SQLite support

## Troubleshooting

### Database Not Found
- Ensure the app has been run at least once
- Check if the app package name matches: `com.example.spending_app`
- Try running the app and creating a transaction first

### Permission Denied
- Emulator: Should work without issues
- Physical device: Requires root access or app-level export feature

### Empty Database
- The database is created on first app launch
- Default categories and wallets are inserted automatically
- Try sending/receiving money via M-Pesa to create transactions

## Security Note

**Important**: Never access production databases directly. This guide is for development and debugging purposes only. Always backup your database before making direct modifications.
