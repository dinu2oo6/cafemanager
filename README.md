# ☕ CafeManager — AI-Powered Café Inventory Manager

An intelligent iOS application for café owners to manage inventory, suppliers, and orders with **AI-powered predictions** that go beyond simple alerts — the app predicts *when* to order, *how much* to order, and identifies waste risks before they happen.

> 💡 Instead of "your stock is low", CafeManager tells you:  
> *"Order 45kg of coffee by Thursday or you'll run out Saturday. Supplier takes 3 days to deliver."*

---

## 📱 Screenshots

*Run the app in Xcode Simulator to see the full UI.*

---

## 🏗 Architecture

**MVVM (Model-View-ViewModel)** with strict separation of concerns:

```
CafeManager/
├── Models/
│   └── DataModels.swift          # All data models + AI prediction types
├── Services/
│   ├── AuthenticationManager.swift # Firebase Auth (login/signup/logout)
│   ├── FirebaseDataService.swift   # Firestore CRUD + real-time listeners
│   └── AIEngines/
│       ├── ConsumptionAnalyzer.swift
│       ├── DemandForecaster.swift
│       ├── StockOptimizer.swift
│       ├── PriceAnalyzer.swift
│       └── WastePredictor.swift
├── ViewModels/
│   ├── InventoryViewModel.swift
│   ├── SupplierViewModel.swift
│   ├── OrderViewModel.swift
│   └── PredictionViewModel.swift
├── Views/
│   ├── Auth/          # LoginView, SignupView
│   ├── MainTab/       # MainTabView (5 tabs)
│   ├── Inventory/     # List + Add/Edit
│   ├── Suppliers/     # List + Add/Edit
│   ├── Orders/        # List + Add/Edit
│   ├── Predictions/   # Dashboard + 3 detail views
│   ├── Settings/      # Profile + Logout
│   └── Components/    # EmptyState, Loading, ErrorBanner
├── Theme/
│   └── AppTheme.swift # Colors, spacing, corner radius
└── CafeManagerApp.swift # Entry point + Firebase init
```

### Architecture Rules
- ✅ Views use ViewModels for all logic
- ✅ Views never import Firebase directly
- ✅ ViewModels never contain UI code
- ✅ Services never call ViewModels
- ✅ AI Engines are pure functions (no UI, no Firebase)
- ✅ `@Published` properties for reactive UI updates

---

## ✨ Features

### 1. Authentication
- Firebase Auth (email/password)
- Sign up with validation
- Persistent login state
- Secure logout

### 2. Inventory Management
- Full CRUD (Create, Read, Update, Delete)
- Search and filter items
- Low stock section highlighted in red
- Stock level progress bars
- Track daily consumption (for AI)
- Track waste/spoilage
- Expiry date tracking
- Profit margin calculation

### 3. Supplier Management
- Full CRUD
- Reliability score (1-5 stars)
- Lead time tracking
- Outstanding balance tracking
- Link suppliers to inventory items

### 4. Order Management
- Create orders linked to items and suppliers
- Track status: Pending → Ordered → Delivered
- Auto-calculate delivery dates from supplier lead time
- Status filter chips
- Swipe actions to update status

### 5. AI Predictions Dashboard
Five AI engines analyze your data:

| Engine | What It Does |
|--------|-------------|
| **Consumption Analyzer** | Detects weekday/weekend patterns, trends, and anomalies |
| **Demand Forecaster** | 7-day demand prediction with confidence levels |
| **Stock Optimizer** | When to order, how much, urgency level (Critical/Warning/Normal) |
| **Price Analyzer** | Margin analysis, loss detection, annual savings suggestions |
| **Waste Predictor** | Expiry risk assessment, waste quantity prediction |

---

## 🤖 AI Engine Details

### Consumption Analyzer
- Calculates daily, weekday, and weekend averages
- Detects trends by comparing recent vs previous weeks
- Identifies anomalies using statistical deviation (2σ threshold)

### Demand Forecaster
- Generates weekday-specific consumption patterns
- Applies trend adjustments to base predictions
- Confidence decreases for further-out days (90% → 55%)

### Stock Optimizer
- `Days until stockout = quantity / daily average consumption`
- `Order date = stockout date - supplier lead time`
- `Suggested quantity = (14 days × avg) + (reorder level × 2)`
- Urgency: **CRITICAL** if days ≤ lead time, **WARNING** if ≤ lead time + 2

### Price Analyzer
- Calculates profit margins per item
- Detects items selling at a loss
- Suggests target costs for 40%+ margin
- Calculates potential annual savings

### Waste Predictor
- `Can consume = daily avg × days until expiry`
- `Will waste = current quantity - can consume`
- Risk levels: High (>50%), Medium (>20%), Low (>0%), Safe (0%)

---

## 🔧 Tech Stack

| Technology | Purpose |
|-----------|---------|
| **Swift 5.9+** | Programming language |
| **SwiftUI** | UI framework (no UIKit) |
| **Firebase Auth** | User authentication |
| **Cloud Firestore** | Real-time NoSQL database |
| **Swift Package Manager** | Dependency management |
| **MVVM** | Architecture pattern |

---

## 🗄 Firestore Schema

```
users/{userId}/
├── inventory/{itemId}
│   ├── name, quantity, unit, reorderLevel
│   ├── costPrice, sellingPrice, supplierId
│   ├── dailyConsumption: [Int] (last 30 days)
│   ├── wasteRecord: [WasteEntry]
│   └── expiryDate, createdAt
├── suppliers/{supplierId}
│   ├── name, email, phone, address
│   ├── leadTimeInDays, paymentTerms
│   ├── onTimeDeliveryRate, totalAmountOwed
│   └── createdAt
└── orders/{orderId}
    ├── itemId, itemName, quantity
    ├── supplierId, supplierName
    ├── orderDate, expectedDeliveryDate
    ├── status, unitPrice, totalCost
    └── createdAt
```

---

## 🚀 Setup Instructions

### Prerequisites
- Xcode 15.0+ (with iOS 16.0+ SDK)
- A Firebase project at [console.firebase.google.com](https://console.firebase.google.com)

### Steps

1. **Clone the repository**
   ```bash
   git clone <repo-url>
   cd CafeManager
   ```

2. **Firebase Setup**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Create a project (or use existing)
   - Add an iOS app with bundle ID: `com.dinesh.CafeManager`
   - Download `GoogleService-Info.plist`
   - Replace the existing file in `CafeManager/GoogleService-Info.plist`

3. **Enable Firebase Services**
   - In Firebase Console → Authentication → Enable Email/Password
   - In Firebase Console → Firestore → Create database (Start in test mode)

4. **Open in Xcode**
   ```bash
   open CafeManager.xcodeproj
   ```

5. **Wait for SPM** — Xcode will automatically resolve Firebase packages

6. **Build & Run** — Select an iOS Simulator and press ⌘R

---

## 🎨 Design

- **Primary**: Coffee Brown (#6B4423)
- **Secondary**: Light Brown (#8B5A2B)
- **Accent**: Cream (#F5F0E8)
- **Success**: Green (#28A745)
- **Warning**: Yellow (#FFC107)
- **Error**: Red (#DC3545)

### UI Highlights
- Gradient login/signup screens
- Health score gauge with animated ring
- Horizontally scrollable alert cards
- Stock level progress bars
- Status filter chips
- Reliability star ratings
- Margin analysis bars
- Waste risk indicators

---

## ✅ Quality Checklist

- [x] Runs on iOS 16+ without crashes
- [x] Firebase Auth login/signup works
- [x] Full CRUD for inventory, suppliers, orders
- [x] Real-time Firestore sync with snapshot listeners
- [x] Search/filter on all list views
- [x] All 5 AI engines calculate predictions
- [x] Predictions dashboard with actionable insights
- [x] Network error handling with error banners
- [x] Empty states on all list views
- [x] Loading spinners during async operations
- [x] Input validation on all forms
- [x] Strict MVVM architecture
- [x] No force unwraps
- [x] No Firebase imports in Views
- [x] Coffee-themed polished UI

---

## 📄 License

This project is created as part of an iOS development internship assignment.

---

Built with ☕ and SwiftUI
