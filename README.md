# Finance & Construction Manager

An **offline-first** Flutter application for managing construction finances, projects, people, vehicles, bills, progress, attachments, and reminders. Core records are stored locally, so normal daily work does not require an internet connection.

---

## Table of Contents

- [What Does This App Do?](#what-does-this-app-do)
- [Getting Started — First Time Setup](#getting-started--first-time-setup)
- [How to Use Each Section](#how-to-use-each-section)
  - [People](#-people)
  - [Sites](#-sites)
  - [Schemes and Projects](#-schemes--projects)
  - [Transactions](#-transactions)
  - [Expenses](#-expenses)
  - [Vehicles and Drivers](#-vehicles--drivers)
  - [Bills](#-bills)
  - [Progress](#-progress)
  - [Attachments](#-attachments)
  - [Reminders](#-reminders)
- [Common Actions (Works Everywhere)](#common-actions-works-everywhere)
- [Tips and Tricks](#tips--tricks)
- [Running the App](#running-the-app)

---

## What Does This App Do?

This app helps you manage a **construction business** from your Windows computer. Think of it as your digital record book for:

| What | Why |
|---|---|
| **People** | Keep a list of your engineers, drivers, labourers, and staff |
| **Sites** | Track your construction sites and their locations |
| **Schemes** | Manage individual projects with budgets and progress |
| **Transactions** | Record money received and money paid out |
| **Expenses** | Log day-to-day costs like fuel, labour, food, materials |
| **Vehicles** | Track trucks, dumpers, and other machines with fuel/maintenance logs |
| **Bills** | Track scheme bills and their payment status |
| **Progress** | Record dated scheme progress updates |
| **Attachments** | Link photos, receipts, and documents to schemes |
| **Reminders** | Track tasks and due dates with priorities |

Everything is saved **on your computer** — even if you close the app and reopen it, all your data is still there.

---

## Getting Started — First Time Setup

> IMPORTANT: The app works best when you set things up in this order. Each section depends on the one before it.

### Step 1 — Add Your People First
Go to **People** and add everyone you work with: engineers, drivers, labourers, staff.
You need people in the system before you can assign them to sites, schemes, or vehicles.

### Step 2 — Add Your Sites
Go to **Sites** and add your construction locations (e.g., "Ring Road Segment A").

### Step 3 — Create Schemes/Projects
Go to **Schemes** and create projects. Each scheme is linked to a site and an engineer.

### Step 4 — Start Recording
Now you can use **Transactions**, **Expenses**, **Vehicles**, **Bills**, **Progress**, and **Reminders**. Link records to the people, sites, and schemes you created wherever relevant.

---

## How to Use Each Section

### People

**What it is:** Your contact book for everyone involved in your work.

**How to open:** Click **People** in the left sidebar (on desktop) or the bottom bar (on mobile).

#### Adding a Person
1. Click the **"Add person"** button (green button, bottom right corner).
2. Fill in the form:
   - **Full name** (required) — The person's complete name.
   - **Phone number** — Their mobile number for contact.
   - **Email** — Their email address (optional).
   - **Address** — Where they live (optional).
   - **Roles** — Check the boxes for what this person does (e.g., Engineer, Driver, Labourer). A person can have more than one role.
   - **Notes** — Any extra information you want to remember.
3. Click **Save** to add them. You will see a green confirmation message at the bottom.

#### Finding a Person
- Use the **Search** box at the top to type a name.
- Use the **Filter by role** chips to show only engineers, or only drivers, etc.
- Toggle **"Show inactive"** to see people you previously deactivated.

#### Managing a Person (Three-dot menu)
Each person card has a **three-dot menu (...)** on the right side with these options:
- **Edit** — Change their details.
- **Deactivate** — Hides them from the main list but keeps their records safe. Use this if someone leaves but you don't want to delete their history.
- **Delete** — Permanently removes them. Use carefully!

> TIP: Use **Deactivate** instead of Delete when a worker leaves. Their past transaction and expense records will stay intact.

---

### Sites

**What it is:** A list of all your construction locations or road segments.

#### Adding a Site
1. Click **"Add site"** (bottom right).
2. Fill in:
   - **Site name** (required) — e.g., "Ring Road Segment A" or "Bypass Project North".
   - **Road information** — e.g., "KM 12 to KM 24, GT Road".
   - **Latitude / Longitude** — GPS coordinates (optional). You can find these on Google Maps by right-clicking a location.
   - **Status** — Choose from:
     - *Planned* — Not started yet.
     - *Active* — Currently under construction.
     - *On Hold* — Paused temporarily.
     - *Completed* — Work is finished.
   - **Notes** — Extra details or landmarks.
3. Click **Save**.

#### Filtering Sites
Use the **status chips** (Active, Completed, On Hold, Planned) to quickly see only the sites you want.

> TIP: Always add your sites before adding schemes, because each scheme must be linked to a site.

---

### Schemes and Projects

**What it is:** Individual projects or work contracts. Each scheme belongs to a site and has a budget, an engineer, and a progress tracker.

> IMPORTANT: You must have at least one **Site** and one **Person (Engineer)** added first before creating schemes.

#### Adding a Scheme
1. Click **"Add scheme"** (bottom right).
2. Fill in:
   - **Scheme code** (required) — A short unique ID, e.g., "SCH-001" or "RR-2024-A".
   - **Scheme name** (required) — Full name, e.g., "Ring Road Widening Phase 1".
   - **Site** — Select which site this project is at.
   - **Budget (Rs.)** — The total approved budget for this scheme.
   - **Engineer** — The person responsible for this project.
   - **Start date / End date** — The planned timeline.
   - **Status** — Choose from:
     - *Initial* — Just created, not started.
     - *Working* — Active work ongoing.
     - *In Progress* — A stage of work completed.
     - *Completed* — Fully done.
     - *Incomplete* — Stopped before completion.
   - **Progress (%)** — Enter how much work is done (0 to 100%).
   - **Description** — Any extra notes about the project.
3. Click **Save**.

#### Reading a Scheme Card
Each scheme shows:
- A **colored status badge** (e.g., green = Completed, blue = In Progress).
- A **progress bar** showing completion percentage.
- The linked **site** and **engineer**.
- The **budget** in Rs.

> TIP: Update the progress percentage regularly so you can see at a glance how each project is advancing.

---

### Transactions

**What it is:** A record of all money coming in and going out. This is like your financial ledger.

#### Summary Bar at the Top
At the very top of the Transactions page you will always see three boxes:
- **Total Received** — All money received so far (shown in green).
- **Total Paid** — All money paid out (shown in red).
- **Net Balance** — The difference (Received minus Paid). If it turns orange, you have paid out more than received.

#### Adding a Transaction
1. Click **"Add Transaction"** (bottom right).
2. Fill in:
   - **Transaction code** (required) — A unique reference, e.g., "TXN-001".
   - **Date** — The date the money was received or paid.
   - **Type** — Select either:
     - *Money Received* — Someone paid you (e.g., government release, client payment).
     - *Money Paid* — You paid someone (e.g., contractor payment, material supplier).
   - **Person** — Who is this transaction with?
   - **Amount (Rs.)** (required) — How much money.
   - **Quantity** — Optional (e.g., if it is a per-unit payment).
   - **Purpose** (required) — What this money is for (e.g., "Labour wages August").
   - **Payment method** — Cash, Bank Transfer, Cheque, etc.
   - **Reference number** — Cheque number, bank slip number, etc.
   - **Linked Scheme / Site** — Attach this transaction to a project.
   - **Remarks** — Any notes.
3. Click **Save**.

#### Filtering Transactions
- Use **"Money Received"** or **"Money Paid"** chips to see only one type.
- Use the **Search** box to find a transaction by code or purpose.

> TIP: Green arrow (down) on a card means money came in. Red arrow (up) means money went out.

---

### Expenses

**What it is:** Day-to-day spending records. Unlike transactions (which are formal payments), expenses are small costs like fuel, food, or office supplies.

#### Total Expenses Bar
At the top you will see **Total Expenses Recorded** — the running total of all expenses entered.

#### Adding an Expense
1. Click **"Add Expense"** (bottom right).
2. Fill in:
   - **Expense code** (required) — e.g., "EXP-001".
   - **Date** — When the expense happened.
   - **Category** — Choose what type of expense this is:
     - *Personal* — Personal costs.
     - *Labour* — Wages, daily labour payments.
     - *Vehicle* — Fuel or vehicle costs (see also Vehicles section).
     - *Office* — Stationery, printing, etc.
     - *Security* — Security guard costs.
     - *Dinner* — Meals for workers or guests.
     - *Material* — Construction materials.
     - *Miscellaneous* — Anything else.
   - **Amount (Rs.)** (required) — Cost in rupees.
   - **Purpose** (required) — Short description, e.g., "Diesel for excavator".
   - **Linked Site / Scheme / Person** — Which project or person does this expense belong to?
   - **Remarks** — Extra notes.
3. Click **Save**.

#### Filtering Expenses
Use the **category chips** to view only a specific type (e.g., tap "Vehicle" to see only vehicle-related expenses).

> TIP: A paperclip icon on an expense card means a receipt or attachment file is saved with that record.

---

### Vehicles and Drivers

**What it is:** Track all your machines and vehicles — trucks, dumpers, excavators, tractors. You can log fuel fills, maintenance events, and trips.

#### Adding a Vehicle
1. Click **"Add Vehicle"** (bottom right).
2. Fill in:
   - **Vehicle number** (required) — The registration plate, e.g., "LEA-1234".
   - **Make and Model** (required) — e.g., "Hino 700" or "CAT Excavator 320".
   - **Vehicle type** — Truck, Dumper, Excavator, Tractor, etc.
   - **Assigned site** — Which site is this vehicle working at?
   - **Assigned driver** — Which person (from your People list) drives this vehicle?
   - **Status** — Active / Under Maintenance / Inactive.
   - **Remarks** — Any notes.
3. Click **Save**.

#### Reading a Vehicle Card
Each vehicle card shows the registration number, make/model, type, driver, site, and status badge.
Click anywhere on the card to **expand it** and see the **log history** for that vehicle.

#### Adding a Fuel / Maintenance / Trip Log
Each vehicle has a **fuel pump icon button** on the right side. Click it to add a log:
- **Log type** — Fuel Fill, Maintenance, Trip, or Other.
- **Date** — When it happened.
- **Amount (Rs.)** — Cost of fuel or maintenance.
- **Quantity (Liters)** — How many liters of fuel (for fuel logs).
- **Driver** — Who was driving.
- **Odometer reading** — Current km reading (optional).
- **Description** — What happened, e.g., "Full tank diesel fill at pump".

To delete a log entry, click the **bin (trash) icon** next to that log in the expanded view.

#### Filtering Vehicles
Use the **status chips** — Active, Under Maintenance, Inactive — to quickly find vehicles.

> TIP: Always tap the vehicle card to expand it before adding a log — it lets you see the existing history too.

---

### Bills

Use **Bills** to record each payment stage for a scheme: Initial, First through Fourth, or Final Bill.

1. Open **Bills** and select **Add Bill**.
2. Select the related scheme, bill type, date, amount, and payment status.
3. Optionally add a bill reference number and remarks, then save.

Use the filters and search box to find a bill later. Scheme cards also provide a **View Bills** action for scheme-specific history.

---

### Progress

Use **Progress** to keep a dated history of work completed on each scheme.

1. Select **Add Progress Update**.
2. Choose the scheme, status, percentage, and update date.
3. Add a result or remarks when useful. For an **Incomplete** update, provide the incomplete reason.

Saving a progress update also updates the parent scheme's status and percentage. You can open a scheme's detailed progress history from its three-dot menu.

---

### Attachments

You can link photos, receipts, documents, and other files to a scheme.

1. Open the scheme's three-dot menu and choose **View Attachments**.
2. Add a file and select its category: Photo, Document, Receipt, or Other File.
3. Optionally record latitude and longitude, then save.

Files are referenced from local storage rather than stored inside the database. Keep important source files in a location that will not be removed or moved.

---

### Reminders

Use **Reminders** for follow-ups, deadlines, and project tasks.

1. Click **Add Reminder**.
2. Enter a title, priority, and optional due date, scheme, site, description, and remarks.
3. Mark the reminder complete with its checkbox when the task is finished.

Use the priority, completion, and search filters to focus on the reminders that need attention. The dashboard also shows overdue and upcoming reminders.

---

## Common Actions (Works Everywhere)

| Action | How to do it |
|---|---|
| **Add a new record** | Click the colored button in the bottom-right corner of any page |
| **Edit a record** | Click the three-dot menu (...) on any card and select **Edit** |
| **Delete a record** | Click (...) then **Delete** and confirm in the popup dialog |
| **Search** | Type in the search box at the top — results update instantly as you type |
| **Filter** | Tap the colored chips (e.g., "Active", "Labour") to show only matching records |
| **Cancel a dialog** | Click **Cancel** or press **Escape** — nothing will be saved |

---

## Tips and Tricks

- **Green message at the bottom** = your change was saved successfully.
- **Red message at the bottom** = something went wrong. Try again.
- The app **works completely offline** — no internet needed at any time.
- Your data is stored in a local database on your computer — it will not be lost if you restart.
- On a **wide screen**, filters appear on the left side. On a **narrow window**, filters appear at the top.
- The **"Show inactive"** toggle on the People page reveals people you have deactivated.
- Fields marked with **\*** or labeled "(required)" must be filled — you cannot save without them.
- You can link a transaction or expense to a **Site**, **Scheme**, and **Person** all at the same time.

---

## Running the App

```powershell
# Install dependencies (first time only):
flutter pub get

# Run on Windows desktop:
flutter run -d windows

# If you get a build error, clean and retry:
flutter clean
flutter run -d windows
```

**Requirements:**
- Windows 10 or later
- Flutter SDK 3.x (Channel stable)
- Visual Studio 2022 or later with the **"Desktop development with C++"** workload installed

---

*Built with Flutter · Offline-first · Data stored locally using SQLite via Drift*
