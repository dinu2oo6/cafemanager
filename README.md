# CafeManager

> A full-featured iOS app built for café managers — real-time inventory, sales, recipes, customers, suppliers, purchase orders, and a local AI assistant that understands natural language, processes supplier bills by photo, and voices answers back.

---

## Visual Tour

### Authentication

| Sign In | Create Account |
|:---:|:---:|
| ![Sign In](Screenshots/login.png) | ![Create Account](Screenshots/signup.png) |
| Email + password login with Firebase Auth | Register with email, password, and confirmation |

---

### Dashboard

| Revenue, Profit & Stock Alerts | Top Sellers, Payments & Low Stock |
|:---:|:---:|
| ![Dashboard](Screenshots/dashboard.png) | ![Dashboard Scrolled](Screenshots/dashboard2.png) |
| Today's revenue card, profit margin, target progress, and active stock alerts | Hourly revenue chart, ranked top sellers, payment breakdown, low stock cards |

---

### Sales

| Sales History | New Sale — Cart | New Sale — Payment & Confirm |
|:---:|:---:|:---:|
| ![Sales](Screenshots/sales.png) | ![New Sale Cart](Screenshots/sales2.png) | ![New Sale Checkout](Screenshots/sales3.png) |
| Revenue ₹2,820 · 3 orders · Profit ₹1,735 with payment filter tabs | Item grid with live cart, quantity controls, and running total | Payment method selector, customer name, discount slider, Complete Sale |

---

### Inventory

| Low Stock Section | All Items | Edit Item — SKU & Details |
|:---:|:---:|:---:|
| ![Low Stock](Screenshots/inventory2.png) | ![All Items](Screenshots/inventory3.png) | ![Edit Details](Screenshots/invemtory.png) |
| 4 items below reorder level with days-left countdown | Full catalogue — cost, sell price, stock level bar, expiry countdown | SKU auto-generation, name, brand, category, quantity, unit, reorder level |

| Edit Item — Pricing, Supplier & Tracking | Edit Item — Live Statistics |
|:---:|:---:|
| ![Pricing](Screenshots/inventory.png) | ![Stats](Screenshots/inventory1.png) |
| Cost/sell prices, margin preview, supplier link, expiry toggle, consumption & waste logging | Computed stats: 1.5 pcs/day avg · 2 days to stockout · profit per unit |

---

### Recipe Cost Analysis

| Recipes — Cost & Margin Overview | Latte — Full Cost Breakdown | Smart Suggestions |
|:---:|:---:|:---:|
| ![Recipes](Screenshots/recipie.png) | ![Cost Detail](Screenshots/recipe2.png) | ![Suggestions](Screenshots/recipie3.png) |
| Latte 100% · Americano 99% · Cappuccino 99% — cost, profit, suggestion count | Ingredient-level breakdown: Coffee 89% of cost, Milk 11%, Sugar 0% | Portion optimise · Bulk buy (save ₹1,944/mo) · Seasonal promotion |

| Stock Availability Per Ingredient | Profitability Ranking | What-If Price Simulator | New Recipe |
|:---:|:---:|:---:|:---:|
| ![Stock](Screenshots/recipie4.png) | ![Profitability](Screenshots/recipie5.png) | ![What-If](Screenshots/recipie6.png) | ![New Recipe](Screenshots/recipie7.png) |
| Coffee stock → 2,050 servings · Milk → 1,030 · Sugar → 1,500 | Menu ranked by margin — #1 Latte 100%, #2 Americano 99%, #3 Cappuccino 99% | Coffee +55%: Latte cost ₹2.71→₹4.03 · Cappuccino margin 99%→98% | Name, category, selling price, serving size, prep time, ingredients |

---

### AI Predictions

| Health Score & Critical Alert | Insights Navigation & Consumption Patterns |
|:---:|:---:|
| ![Predictions](Screenshots/predictions.png) | ![Predictions Scrolled](Screenshots/predictioins1.png) |
| Score 65 — Eggs: 2 days stock, supplier needs 3 days → order 41 pcs by 3 May | Demand Forecast · Price Optimisation (8 low-margin) · Waste Prediction (2 at risk) · daily/weekday/weekend grid |

---

### Demand Forecast

| 7-Day Demand Forecast with Confidence Decay |
|:---:|
| ![Demand Forecast](Screenshots/demand.png) |
| Coffee BRU — item selector tabs · daily avg 4.5 · Mon 1.0 kg 90% → Sat 0.0 kg 65% confidence |

---

### Waste Prediction

| Waste Risk Overview & At-Risk Items | Items Without Expiry Set |
|:---:|:---:|
| ![Waste](Screenshots/waste.png) | ![No Expiry](Screenshots/waste2.png) |
| Sugar Corp EXPIRED 100% risk · Milk 10 days 90% risk (93 L waste) · Coffee 0% safe | 8 items with no expiry date listed for reference |

---

### Price Optimisation

| Margin Overview & Annual Savings Insights |
|:---:|
| ![Price Optimisation](Screenshots/optimization.png) |
| 0 at loss · 8 low margin · 3 healthy — Eggs: find supplier under ₹7/pcs to save ₹2,592/year |

---

### Analytics

| Overview & Revenue Trend | Item Performance, Margin Analysis & Customer Metrics |
|:---:|:---:|
| ![Analytics](Screenshots/analytics.png) | ![Analytics Scrolled](Screenshots/analytics2.png) |
| Week: Revenue ₹8,796 · Profit ₹4,696 · 8 orders · revenue trend bar chart by day | Coffee 13 sold ₹5,033 · Milk 97.6% margin · Sugar Corp 93.3% · waste & customer metrics |

---

### Suppliers

| Supplier Directory |
|:---:|
| ![Suppliers](Screenshots/suppliers.png) |
| Hemraj 3★ · 13d lead · owed ₹2,889 — Dinesh 4★ · 2d lead · owed ₹1,000 — Shailk 4★ · 13d lead · owed ₹1,300 |

---

### Purchase Orders

| Orders List — Status & ETA | New Order Form |
|:---:|:---:|
| ![Orders](Screenshots/orders.png) | ![New Order](Screenshots/orders2.png) |
| Pending orders with units, cost, order date, and ETA — overdue ETA shown in red | Select item + supplier · quantity · unit price · auto-calculated delivery date |

---

### AI Assistant

| Natural Language Chat | Supplier Bill Scanning | Batch Inventory Update |
|:---:|:---:|:---:|
| ![AI Chat](Screenshots/aiassistant.png) | ![Bill Scanning](Screenshots/aiassistant2.png) | ![Batch Update](Screenshots/aiassistant3.png) |
| "Sales this month" → Orders: 8 · Revenue: ₹8,796 · Profit: ₹4,696 · Avg Order: ₹1,099 | Supplier bill photo → llava:13b extracts 10 line items and updates each one live | All items batch-updated from bill · "Add 50 kgs coffee" voice follow-up → Coffee 50→100 kg |

---

## Table of Contents

- [Tech Stack](#tech-stack)
- [Architecture — MVVM](#architecture--mvvm)
- [Firebase Integration](#firebase-integration)
- [Data Models](#data-models)
- [Features & Flows](#features--flows)
  - [Authentication](#authentication-1)
  - [Dashboard](#dashboard-1)
  - [Sales & Transactions](#sales--transactions)
  - [Inventory Management](#inventory-management)
  - [Recipe Cost Analysis](#recipe-cost-analysis-1)
  - [Customers & Loyalty](#customers--loyalty)
  - [Suppliers & Purchase Orders](#suppliers--purchase-orders)
  - [Analytics](#analytics-1)
  - [AI Prediction Engines](#ai-prediction-engines)
  - [AI Assistant](#ai-assistant-1)
- [Setup & Run](#setup--run)
- [Project Structure](#project-structure)

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI (iOS 16+, 100% declarative) |
| Backend / Database | Firebase Cloud Firestore |
| Authentication | Firebase Auth (email + password) |
| Local AI | Ollama — `gemma:7b` (text), `llava:13b` (vision) |
| Speech-to-Text | iOS `SFSpeechRecognizer` |
| Text-to-Speech | `AVSpeechSynthesizer` |
| OCR / Bill Scanning | Vision framework (`VNRecognizeTextRequest`) |
| PDF Parsing | PDFKit |
| Push Notifications | `UserNotifications` framework |
| Concurrency | Swift `async/await`, `@MainActor` |
| Package Management | Swift Package Manager (no CocoaPods) |

---

## Architecture — MVVM

CafeManager follows strict MVVM with three fully separated layers. No view knows about Firestore. No service knows about SwiftUI.

```
┌───────────────────────────────────────────────────────────┐
│                      VIEWS (SwiftUI)                      │
│  Pure display + user input. Zero business logic.          │
│  Observe @Published properties via @StateObject /         │
│  @EnvironmentObject. Forward actions to ViewModel.        │
└─────────────────────────┬─────────────────────────────────┘
                          │  @Published bindings (two-way)
┌─────────────────────────▼─────────────────────────────────┐
│                    VIEWMODELS                             │
│  @MainActor ObservableObjects.                            │
│  Filter, sort, validate, coordinate service calls.        │
│  Expose: filteredList, isLoading, errorMessage,           │
│          computed stats, derived UI state.                │
└─────────────────────────┬─────────────────────────────────┘
                          │  async/await calls
┌─────────────────────────▼─────────────────────────────────┐
│                     SERVICES                              │
│  FirebaseDataService — all Firestore CRUD + listeners     │
│  AuthenticationManager — Firebase Auth wrapper            │
│  CafeAIService — Ollama LLM integration + tool dispatch   │
│  VoiceManager — speech I/O                               │
│  DocumentParser — OCR + bill parsing                      │
│  AI Engines — 5 deterministic analytics engines           │
│  StockAlertNotificationManager — local push alerts        │
└───────────────────────────────────────────────────────────┘
```

### Key MVVM Conventions

**Views** receive a single ViewModel via `@StateObject` or `@ObservedObject`. They never call Firestore directly. Every user gesture (button tap, swipe-to-delete, form submit) is a call into the ViewModel.

**ViewModels** hold all mutable published state. They call services using `async/await` and switch back to the main actor with `@MainActor`. Every ViewModel exposes:
- `isLoading: Bool` — drives loading spinners
- `errorMessage: String?` — drives the `ErrorBannerView` overlay
- Filtered and sorted collections derived from raw data

**Services** are singletons injected into the view hierarchy as `@EnvironmentObject` from `CafeManagerApp`. ViewModels observe `@Published` collections on `FirebaseDataService` and re-derive their own filtered state whenever the underlying data changes.

---

## Firebase Integration

### Authentication Flow

```
App Launch
    │
    ▼
Auth State Listener
    ├── signed in ──► MainTabView  (full app)
    └── signed out ──► LoginView
                           │
                    ┌──────┴──────┐
                    │             │
                 Sign In       Sign Up
                    │             │
                    └──── Firebase Auth ────► MainTabView
```

`AuthenticationManager` maps 14+ Firebase error codes to plain-English messages:

| Firebase Code | User Message |
|---|---|
| `wrongPassword` | "Incorrect password. Please try again." |
| `userNotFound` | "No account found with this email." |
| `networkError` | "Network unavailable. Check your connection." |
| `invalidAPIKey` | "Firebase configuration error. Contact support." |
| `emailAlreadyInUse` | "This email is already registered." |

On logout, all Firestore snapshot listeners are detached so no stale data leaks between sessions.

---

### Firestore Data Structure

All data is scoped to the authenticated user — no cross-user data access is possible.

```
users/{userId}/
├── inventory/       — InventoryItem documents
├── suppliers/       — Supplier documents
├── orders/          — Order documents
├── sales/           — SaleTransaction documents
├── customers/       — Customer documents
├── staff/           — StaffMember documents
└── recipes/         — Recipe documents
```

### Real-Time Listeners

`FirebaseDataService` attaches one `addSnapshotListener` per collection on login. Every Firestore write — from any device or the web console — instantly propagates to all ViewModels subscribed to the affected `@Published` array. No manual refresh, no polling.

### Write Strategy

All updates use `setData(_, merge: true)`. Updating a single field never overwrites unmodified fields on the same document — critical when multiple ViewModels update different parts of the same `InventoryItem` concurrently.

### Consumption Backfilling

Every consumption log is stored as a `ConsumptionEntry { id, quantity, date }`. On each write, the service rebuilds the rolling 30-day `dailyConsumption` array from all entries sorted by date. This means retroactive data entry is fully reflected in all AI predictions without data loss.

---

## Data Models

All models are `Codable` and `Identifiable`. Firestore metadata is handled by `@DocumentID` and `@ServerTimestamp` annotations.

### InventoryItem

| Field | Type | Description |
|---|---|---|
| `sku` | String | Auto-generated (e.g., `BEV-001`, `EGG-001`) |
| `name` | String | Display name |
| `brand` | String | Optional brand (e.g., Amul, BRU) |
| `category` | ItemCategory | Dairy / Beverages / Bakery / … (10 categories) |
| `quantity` | Double | Current stock |
| `unit` | String | kg / L / pcs / g / ml |
| `reorderLevel` | Double | Threshold for low-stock alerts |
| `costPrice` | Double | Purchase cost per unit |
| `sellingPrice` | Double | Retail price per unit |
| `supplierId` | String? | Link to Supplier document |
| `expiryDate` | Date? | For WastePredictor engine |
| `dailyConsumption` | [Double] | Rolling 30-day array (rebuilt on each log) |
| `consumptionLog` | [ConsumptionEntry] | Dated usage entries (supports backfill) |
| `wasteRecord` | [WasteEntry] | Dated waste entries with reason strings |

**Computed properties on the model:**

| Property | Formula |
|---|---|
| `isLow` | `quantity <= reorderLevel` |
| `averageDailyConsumption` | `sum(dailyConsumption) / count` |
| `daysUntilStockout` | `quantity / averageDailyConsumption` (999 if zero) |
| `profitPerUnit` | `sellingPrice - costPrice` |
| `marginPercentage` | `(profitPerUnit / sellingPrice) × 100` |
| `stockLevelPercentage` | `quantity / (reorderLevel × 3)` (for progress bars) |

### SaleTransaction

| Field | Type | Description |
|---|---|---|
| `items` | [SaleItem] | Array of `{itemId, itemName, quantity, unitPrice, costPrice}` |
| `subtotal` | Double | Sum before discount |
| `discount` | Double | Flat discount applied |
| `totalAmount` | Double | Amount charged |
| `paymentMethod` | PaymentMethod | Cash / Card / UPI / Wallet |
| `customerId` | String? | Optional customer link |
| `date` | Date | Transaction timestamp |

Computed: `totalCOGS`, `grossProfit`, `itemCount`

### Recipe

| Field | Type | Description |
|---|---|---|
| `name` | String | Menu item name |
| `category` | RecipeCategory | Hot Beverages / Cold / Snacks / Desserts / Meals / Other |
| `ingredients` | [RecipeIngredient] | `{itemId, itemName, quantity, unit}` |
| `sellingPrice` | Double | Menu price |
| `servingSize` | String | e.g., "1 cup" |
| `preparationTime` | Int | Minutes |

### Customer

| Field | Type | Description |
|---|---|---|
| `totalSpent` | Double | Lifetime spend |
| `visitCount` | Int | Total visits |
| `lastVisitDate` | Date | For churn risk calculation |
| `favoriteItems` | [String] | Item names from purchase history |

Computed: `loyaltyTier` (Gold/Silver/Bronze), `isChurnRisk` (no visit in 14+ days), `averageOrderValue`, `daysSinceLastVisit`

---

## Features & Flows

### Authentication

**Sign Up flow:**
1. User enters email, password, confirm password
2. `AuthenticationManager.signUp()` creates Firebase Auth user
3. Auth state listener fires → `MainTabView` loads
4. `FirebaseDataService` initializes snapshot listeners for the new UID

**Sign In flow:**
1. User enters email + password
2. `AuthenticationManager.signIn()` calls Firebase Auth
3. Errors mapped to friendly messages and shown in `ErrorBannerView`
4. On success, same listener-driven navigation as sign-up

---

### Dashboard

The Dashboard is the home screen — a single-glance operational summary rebuilt every time today's sales or inventory changes.

| Section | Content |
|---|---|
| Greeting | "Good Morning / Afternoon / Evening" + today's date |
| Revenue Card | Today's revenue, profit, margin %, target progress bar |
| Alerts | Red banners for items below reorder level or expiring within 3 days |
| Quick Stats | Orders today, unique customers, gross profit, margin % |
| Hourly Revenue Chart | Line chart aggregating revenue by hour of day |
| Top Selling Today | Items ranked by revenue with quantity sold |
| Payment Breakdown | Cash / Card / UPI / Wallet distribution |
| Low Stock Cards | Scrollable row of at-risk items with reorder shortcut |

**Data flow:**
```
FirebaseDataService.sales (listener)
        │
        ▼
DashboardViewModel
  ├── filters to today (startOfDay..endOfDay)
  ├── groups by hour → hourlyRevenue array
  ├── aggregates by item → topSellingItems
  ├── counts unique customerIds → uniqueCustomers
  └── exposes @Published state
        │
        ▼
DashboardView (reads @Published, zero computation)
```

---

### Sales & Transactions

**SalesView** shows the full transaction history with filter and search.

- Payment method quick-toggle (All / Cash / Card / UPI / Wallet)
- Search by item name or customer name
- Today's summary card: orders, revenue, profit, average order value
- Swipe-to-delete with confirmation

**NewSaleView — recording a sale:**
1. Search and select items from the inventory grid
2. Enter quantity per item (validated against current stock)
3. Unit price auto-populated from `InventoryItem.sellingPrice`
4. Add optional discount via slider
5. Select payment method (Cash / Card / UPI / Wallet)
6. Optionally link a customer by name
7. Tap **Complete Sale** → writes transaction + calls `logConsumption()` for each line item

---

### Inventory Management

**InventoryListView:**
- Two sections: **Low Stock** (red header, sorted by urgency) and **All Items**
- Each row: name, SKU, category, cost, sell price, stock level progress bar, days left
- Search by name, brand, or SKU
- Swipe-to-delete with confirmation

**AddEditInventoryView — all fields:**
- SKU (auto-generated as `CAT-###` if left blank)
- Name, brand, category picker (10 categories)
- Quantity + unit picker
- Cost price + selling price with live margin preview
- Reorder level (triggers low-stock alert)
- Supplier dropdown (linked to Supplier collection)
- Expiry date toggle + date picker
- Log Daily Consumption button (dated entry, supports backfill)
- Log Waste / Spoilage button
- Live statistics panel: daily avg, days to stockout, profit per unit, consumption days

---

### Recipe Cost Analysis

Three-tab screen for profitability intelligence.

#### Tab 1 — Recipes

All recipes with cost, profit, and margin at a glance. Tip badge shows the count of AI suggestions available. Tap any recipe to open the full cost breakdown.

**ProductCostDetailView:**
- Ingredient breakdown table: name, quantity per serving, unit, cost per unit, line total, % of recipe cost
- Cost summary: ingredient cost + waste factor = true production cost
- Profit per serving and margin %
- Stock availability: how many servings possible from current inventory
- Smart Suggestions list

#### Tab 2 — Menu Profitability

All recipes ranked by monthly profit (profit per serving × monthly sales). Shows cost, selling price, margin %, monthly revenue, and monthly profit ranked top to bottom. Immediately shows which items to promote and which to review.

#### Tab 3 — What-If Scenarios

1. Select an ingredient
2. Set a % price change with the slider
3. Tap **Simulate** — every affected recipe shows old cost → new cost and old margin → new margin

**ProductCostAnalyzer suggestion types:**

| Type | Colour | Trigger |
|---|---|---|
| Substitution | Blue | Cheaper alternative exists in inventory |
| Portion Optimize | Purple | Serving size adjustment improves margin |
| Bulk Buying | Teal | Monthly volume qualifies for bulk discount |
| Margin Alert | Red | Recipe sold below cost or margin < 10% |
| Waste Reduction | Orange | Ingredient waste > 20% |
| Price Adjustment | Green | Margin < 20% — recommend price increase |
| Seasonal | Mint | Ingredient has seasonal cost pattern |

---

### Customers & Loyalty

**CustomerListView:**
- Stats bar: total customers, gold / silver / bronze counts, churn risk count
- Loyalty tier filter bar
- Search by name, email, or phone
- Each row: name, tier badge, visit count, total spent, churn risk flag

**Loyalty tiers (computed, not manually assigned):**

| Tier | Criteria |
|---|---|
| Gold | 50+ visits **and** ₹5,000+ spent |
| Silver | 20+ visits **and** ₹1,500+ spent |
| Bronze | Everyone else |

**Churn Risk:** `isChurnRisk = daysSinceLastVisit > 14` — computed property on the model, no background job needed.

---

### Suppliers & Purchase Orders

**SupplierListView:**
- Name, email, phone, lead time in days, payment terms
- Star rating: `reliabilityStars = onTimeDeliveryRate / 20` (1–5 scale)
- Outstanding balance per supplier

**OrderListView:**
- Status filter bar: All / Pending / Ordered / Delivered / Cancelled
- Each order: item name, supplier, quantity, total cost, order date, ETA (red if overdue)

**Purchase order flow:**
```
AddEditOrderView
    │  item, supplier, quantity, unit price
    │  delivery date auto-calculated from supplier lead time
    ▼
FirebaseDataService.addOrder()
    │
    ▼
OrderListView updates in real time
    │
    │  manager taps "Mark Delivered"
    ▼
FirebaseDataService.updateOrderStatus(.delivered)
    + FirebaseDataService.updateInventoryQuantity(+quantity)
```

---

### Analytics

Period-selectable: **Today / Week / Month**

| Section | Content |
|---|---|
| Overview Cards | Revenue, Profit, Orders, Waste Value — each with trend % |
| Revenue Trend | Bar chart by day over the selected period |
| Item Performance | All items ranked by revenue with quantity sold |
| Margin Analysis | Cards for high-margin stars and at-risk low-margin items |
| Waste Summary | Total waste quantity and value |
| Customer Metrics | Unique customers, repeat rate, churn risk count, AOV, top customer |

---

## AI Prediction Engines

Five deterministic analytics engines run entirely on-device — no API calls, no latency, no internet dependency. They use statistical formulas on real operational data: transparent, auditable, and instantly tunable.

### Health Score

`PredictionViewModel` runs all five engines across every inventory item and produces a single 0–100 **Health Score**:

```
healthScore = 100
            − (criticalAlerts  × 15)
            − (warningAlerts   × 5)
            − (highWasteItems  × 10)
            − (negativeMargins × 10)
```

Color: **green** (70+), **yellow** (40–69), **red** (<40).

---

### Engine 1 — ConsumptionAnalyzer

**Input:** `InventoryItem.dailyConsumption` (rolling 30-day array)

| Output Field | Formula |
|---|---|
| `dailyAverage` | `sum / count` |
| `weekdayAverage` | Average of Mon–Fri buckets |
| `weekendAverage` | Average of Sat–Sun buckets |
| `trendPercentage` | `((last7avg − prev7avg) / prev7avg) × 100` |
| `isAnomaly` | `latestValue > mean ± 2σ` |

---

### Engine 2 — DemandForecaster

**Input:** `InventoryItem`, horizon (default 7 days)

| Output Field | Formula |
|---|---|
| `predictedQuantity` | `weekdayBaseline × (1 + trend/100)` |
| `confidence` | `90% − (dayIndex × 5%)` |

Builds a per-weekday consumption pattern from history and applies the current trend as a multiplier. Confidence decays 5% per day.

---

### Engine 3 — StockOptimizer

**Input:** `InventoryItem`, linked `Supplier`

| Output Field | Formula |
|---|---|
| `daysUntilStockout` | `quantity / avgDailyConsumption` |
| `recommendedOrderDate` | `max(0, daysUntilStockout − supplierLeadTime)` |
| `suggestedQuantity` | `avgConsumption × 14 + reorderLevel × 2` |

| Urgency | Condition |
|---|---|
| Critical | `daysUntilStockout ≤ supplierLeadTime` — will run out before delivery |
| Warning | `daysUntilStockout ≤ supplierLeadTime + 2` |
| Normal | Comfortable margin |

---

### Engine 4 — WastePredictor

**Input:** `InventoryItem` with `expiryDate`

| Output Field | Formula |
|---|---|
| `daysUntilExpiry` | `expiryDate − today` |
| `canConsume` | `avgDailyConsumption × daysUntilExpiry` |
| `predictedWaste` | `max(0, currentQuantity − canConsume)` |
| `wastePercentage` | `predictedWaste / currentQuantity × 100` |

| Threshold | Risk Level | Action |
|---|---|---|
| > 50% | High | Reduce next order significantly, consider discounting |
| > 20% | Moderate | Order less next time |
| > 0% | Low | Monitor |
| 0% | None | On track — stock will be consumed before expiry |

---

### Engine 5 — PriceAnalyzer

**Input:** `[InventoryItem]`, `[Supplier]`

| Output Field | Formula |
|---|---|
| `marginPercentage` | `(selling − cost) / selling × 100` |
| `monthlyQuantity` | `avgDailyConsumption × 30` |
| `annualSavings` | `(costPrice − targetCost) × monthlyQty × 12` |

| Margin Band | Message |
|---|---|
| < 0% | "Selling at a loss — raise price immediately" |
| 0–20% | "Low margin — find supplier under ₹X to save ₹Y/year" |
| 20–40% | "Moderate margin — monthly revenue ₹X" |
| > 40% | "Strong margin — annual profit potential ₹X" |

---

## AI Assistant

The AI Assistant is a full-featured chat interface connected to a locally running Ollama instance. It reads live app data via tool calls, processes supplier bills from photos, and speaks answers aloud.

### Architecture

```
AIAssistantView
    │  user message (text / voice / image / PDF)
    ▼
AIAssistantViewModel
    │  preprocesses image (OCR + bill parsing)
    │  manages chat history and confirmation state
    ▼
CafeAIService
    │  sends to Ollama (gemma:7b text / llava:13b vision)
    │  parses tool calls from response
    │  dispatches read-only calls immediately
    │  routes mutating calls through confirmation dialog
    ▼
Ollama (localhost:11434) — fully offline, zero cloud dependency
```

### Models

| Model | Role |
|---|---|
| `gemma:7b` | All text chat, tool call generation and parsing, response formatting |
| `llava:13b` | Image analysis — bill scanning, photo context, item extraction |

---

### Tool Library — 30+ Tools Across 6 Domains

**Inventory (14 tools)**

| Tool | Action |
|---|---|
| `get_inventory_status(item_name?)` | Quantities, reorder levels, days until stockout |
| `get_low_stock_items()` | All items below reorder level |
| `get_demand_forecast(item_name, days?)` | 7-day predicted consumption |
| `get_waste_risks()` | Expiry-based waste predictions |
| `get_consumption_insights(item_name?)` | Daily/weekday/weekend averages, trend, anomaly flag |
| `get_item_pricing(item_name?)` | Cost, selling price, margin % |
| `update_stock_quantity(item_name, quantity, unit?)` | Add or subtract from stock |
| `add_inventory_item(name, quantity, unit, ...)` | Create new inventory item |
| `update_cost_price(item_name, new_cost)` | Change purchase cost |
| `update_selling_price(item_name, new_price)` | Change retail price |
| `update_expiry_date(item_name, expiry_date)` | Set or update expiry |
| `delete_inventory_item(item_name)` | Remove item |
| `log_consumption(item_name, amount)` | Record daily usage |
| `log_waste(item_name, amount, reason)` | Record waste with reason |

**Sales (4 tools)**

| Tool | Action |
|---|---|
| `get_sales_summary(period?)` | Revenue, profit, orders, avg order value |
| `get_today_sales()` | Today's transactions |
| `get_top_selling_items(period?, limit?)` | Ranked by revenue |
| `record_sale(item_name, quantity, payment_method, ...)` | Log sale + auto-deduct inventory |

**Orders (5 tools)**

| Tool | Action |
|---|---|
| `get_orders(status?)` | List orders with optional status filter |
| `create_purchase_order(item_name, quantity, supplier_name, ...)` | Create order, auto-calculate delivery date |
| `update_order_status(item_name, new_status)` | Advance or change status |
| `cancel_order(item_name)` | Mark cancelled |
| `delete_order(item_name)` | Delete |

**Suppliers (4 tools)**

| Tool | Action |
|---|---|
| `get_suppliers()` | All suppliers with lead times and ratings |
| `add_supplier(name, email, phone, ...)` | Create supplier |
| `update_supplier(name, ...)` | Update fields |
| `delete_supplier(name)` | Remove |

**Customers (4 tools)**

| Tool | Action |
|---|---|
| `get_customers(name?)` | All customers with loyalty tiers |
| `add_customer(name, email, phone, notes?)` | Register |
| `update_customer(name, ...)` | Update fields |
| `delete_customer(name)` | Remove |

**Recipes & Cost Analysis (7 tools)**

| Tool | Action |
|---|---|
| `get_recipes(name?)` | List recipes with cost / price / margin |
| `analyze_product_cost(recipe_name)` | Full cost breakdown + AI suggestions |
| `get_menu_profitability()` | Recipes ranked by monthly profit |
| `what_if_price_change(ingredient, percent_change)` | Simulate ingredient cost impact |
| `add_recipe(name, category, selling_price, ingredients, ...)` | Create recipe |
| `delete_recipe(recipe_name)` | Remove |
| `get_daily_briefing()` | Snapshot: low stock, today's sales, pending orders, expiring items, churn risks |

---

### Tool Dispatch Flow

```
Ollama response
    │
    ▼
Parse JSON tool call
    │
    ├── Read-only tool (get_*)
    │       ▼
    │   Execute immediately → format result → display to user
    │
    └── Mutating tool (update_*, add_*, delete_*, record_*, log_*)
            ▼
        Show PendingConfirmation dialog
            │
            ├── User confirms → execute → AI receives result → continues
            └── User denies → cancelled → AI informed → continues
```

Every mutating action shows the specific action and data before it executes — nothing is written to Firestore without explicit user approval.

---

### Bill Scanning Flow

1. User picks a photo (camera or photo library) or a PDF of a supplier bill
2. `DocumentParser` preprocesses: contrast enhancement → thresholding → resize to max 1536px JPEG
3. `VNRecognizeTextRequest` runs OCR in accurate mode
4. Multi-strategy parser extracts line items:
   - Strategy 1: regex patterns matching `"Item qty unit price"` formats
   - Strategy 2: keyword detection for units (kg, L, pcs, g, ml)
   - Fallback: image sent to `llava:13b` for vision-based extraction
5. Each complete item → `update_stock_quantity` or `add_inventory_item` tool call
6. Incomplete items (missing quantity or price) → user is prompted to fill in
7. Loops up to 4 iterations until all items are processed

---

### Voice I/O

**Speech-to-text:** `SFSpeechRecognizer` (en-US, on-device). Tap microphone → speak → tap stop → transcript populates the message field.

**Text-to-speech:** `AVSpeechSynthesizer` reads assistant responses aloud with audio ducking so background music lowers while the assistant speaks.

---

## Setup & Run

### Prerequisites

| Tool | Version | Install |
|---|---|---|
| Xcode | 15.0+ | Mac App Store |
| iOS Simulator | iOS 16+ | Xcode → Platforms |
| Ollama | Latest | [ollama.com](https://ollama.com) |
| Firebase Project | — | [console.firebase.google.com](https://console.firebase.google.com) |

---

### Step 1 — Clone

```bash
git clone https://github.com/thedineshkotipalli/CafeManager.git
cd CafeManager
```

---

### Step 2 — Firebase Setup

1. Go to the [Firebase Console](https://console.firebase.google.com) and create a project
2. Add an iOS app with bundle ID: `com.dinesh.CafeManager`
3. Download `GoogleService-Info.plist` and replace the file at:
   ```
   CafeManager/GoogleService-Info.plist
   ```
4. Enable in the Firebase Console:
   - **Authentication** → Sign-in method → Email/Password → Enable
   - **Firestore Database** → Create database → Start in test mode

No CocoaPods steps — Firebase is integrated via Swift Package Manager.

---

### Step 3 — Install and Start Ollama

```bash
# Install Ollama
brew install ollama

# Pull the text model (chat + tool call generation)
ollama pull gemma:7b

# Pull the vision model (bill scanning + image analysis)
ollama pull llava:13b

# Start the server
ollama serve
```

Ollama listens at `http://localhost:11434`.

**iOS Simulator** can reach `localhost` on the Mac directly — no changes needed.

**Physical iPhone** must be on the same Wi-Fi network as the Mac. Update [CafeManager/Config/APIKeys.swift](CafeManager/Config/APIKeys.swift):

```swift
// Find your Mac's local IP
// bash: ipconfig getifaddr en0

enum LocalLLMConfig {
    static let baseURL = "http://192.168.1.X:11434"  // replace X
}
```

---

### Step 4 — Build and Run

```bash
open CafeManager.xcodeproj
```

Select a simulator or connected device (iOS 16+) in the Xcode toolbar, then press `⌘R`.

---

### Ollama Management Commands

```bash
# List installed models
ollama list

# Check running models
ollama ps

# Test the text model
ollama run gemma:7b "Hello"

# Stop the server
pkill ollama

# Remove a model
ollama rm llava:13b
```

---

## Project Structure

```
CafeManager/
├── CafeManagerApp.swift                    — App entry, Firebase init, environment injection
├── Config/
│   └── APIKeys.swift                       — Ollama base URL, model names, system prompt
├── Models/
│   ├── DataModels.swift                    — All Codable structs, enums, AI result types
│   └── ChatMessage.swift                   — Chat message and confirmation dialog models
├── Services/
│   ├── AuthenticationManager.swift         — Firebase Auth wrapper, 14+ error mappings
│   ├── FirebaseDataService.swift           — All Firestore CRUD + real-time listeners
│   ├── StockAlertNotificationManager.swift — Local push notification scheduling
│   ├── AI/
│   │   ├── CafeAIService.swift             — Ollama integration, 30+ tools, dispatch loop
│   │   ├── VoiceManager.swift              — SFSpeechRecognizer + AVSpeechSynthesizer
│   │   └── DocumentParser.swift            — OCR, image preprocessing, bill parsing
│   └── AIEngines/
│       ├── ConsumptionAnalyzer.swift       — Usage trend, weekday/weekend split, anomaly
│       ├── DemandForecaster.swift          — 7-day forecast with confidence decay
│       ├── StockOptimizer.swift            — Stockout date, reorder quantity, urgency
│       ├── WastePredictor.swift            — Expiry-based waste risk calculation
│       ├── PriceAnalyzer.swift             — Margin analysis, annual savings
│       └── ProductCostAnalyzer.swift       — Recipe cost breakdown, what-if, suggestions
├── ViewModels/
│   ├── DashboardViewModel.swift            — KPI aggregation, hourly chart, alerts
│   ├── SalesViewModel.swift                — Sales filtering and daily summary
│   ├── InventoryViewModel.swift            — Inventory filtering, low-stock split
│   ├── RecipeViewModel.swift               — Recipe list, cost analysis, profitability
│   ├── CustomerViewModel.swift             — Customer filtering, loyalty, churn
│   ├── OrderViewModel.swift                — Order filtering by status
│   ├── SupplierViewModel.swift             — Supplier CRUD coordination
│   ├── PredictionViewModel.swift           — Orchestrates all 5 AI engines, health score
│   └── AIAssistantViewModel.swift          — Chat state, voice, image pipeline, confirmations
├── Views/
│   ├── Auth/                               — LoginView, SignupView
│   ├── MainTab/                            — MainTabView (Dashboard / Sales / Inventory / More)
│   ├── Dashboard/                          — DashboardView
│   ├── Sales/                              — SalesView, NewSaleView
│   ├── Inventory/                          — InventoryListView, AddEditInventoryView
│   ├── Recipes/                            — RecipeCostAnalysisView, AddEditRecipeView,
│   │                                         ProductCostDetailView
│   ├── Customers/                          — CustomerListView, AddEditCustomerView
│   ├── Suppliers/                          — SupplierListView, AddEditSupplierView
│   ├── Orders/                             — OrderListView, AddEditOrderView
│   ├── Predictions/                        — PredictionDashboardView, DemandForecastView,
│   │                                         WastePredictionView, PriceOptimizationView
│   ├── Analytics/                          — AnalyticsView
│   ├── AIAssistant/                        — AIAssistantView, ChatBubbleView
│   ├── Settings/                           — SettingsView
│   └── Components/                         — ErrorBannerView, EmptyStateView, LoadingView
└── Theme/
    └── AppTheme.swift                      — Colors, typography, spacing constants
```
