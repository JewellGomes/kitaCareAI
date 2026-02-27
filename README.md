# KitaCare AI

## 📖 Project Description
KitaCare AI — Project Summary
Malaysia is no stranger to generosity. When disasters strike, donations pour in ,yet aid still fails to reach those who need it most. The December 2021 floods displaced over 71,000 people and affected more than 125,000 nationwide, yet relief efforts were hampered not by a lack of resources, but a breakdown in coordination. Donations flowed toward visible, popular causes while urgent needs went unmet. NGOs drowned in irrelevant goods. Donors, unable to track where their contributions went, lost trust and disengaged. Vulnerable communities ( particularly B40 households in flood-prone states like Kelantan, Terengganu, and Pahang) were left waiting during the most critical response window.
This is the problem KitaCare AI was built to solve.
KitaCare AI is an AI-powered donation coordination platform that acts as a central intelligence layer connecting donors, NGOs, and communities in real time. Rather than letting aid flow arbitrarily, KitaCare ensures it flows intelligently ,directing the right resources to the right people at the right time. Donors receive AI-driven recommendations on where help is most urgently needed. NGOs can report live needs, confirm receipts, and demonstrate real-world impact. Communities gain visibility, dignity, and timely support.
At its core, KitaCare AI is powered by Google Gemini, which transforms unstructured field reports and community data into actionable guidance for relief workers and personalized recommendations for donors. Firebase Firestore ensures every update , a shipment dispatched, a need fulfilled, a family helped , is reflected across all dashboards in real time, creating end-to-end transparency that rebuilds donor trust.
Beyond disaster response, KitaCare AI aligns with a broader vision of systemic change. It directly supports SDG 11 by reducing the human and economic toll of disasters through smarter coordination, SDG 1 by protecting Malaysia's most vulnerable populations from the compounding effects of poorly distributed aid, and SDG 9 by demonstrating how AI and digital innovation can modernize and strengthen humanitarian infrastructure at scale.
KitaCare AI does not just make donating easier , it makes donating matter. By turning a fragmented, reactive relief system into a transparent, data-driven, and proactive platform, it embodies a simple but powerful principle: Rakyat Menjaga Rakyat ; the people taking care of their own.

---

## 🏗️ Project Documentation & Architecture
*KitaCare AI - Solution Architecture Document*  
*Smart Donations That Reach Those Who Need It Most*  
*Prepared by: CHATHYA | Section: Technical Architecture*

### 1. Architecture Overview
KitaCare AI is a cross-platform mobile application built using Flutter, connected to a Google Firebase backend, and powered by Google Gemini AI. The platform connects three user roles — Individual Donors, Malaysian NGOs, and Logistics Couriers — through a shared, real-time infrastructure that directs aid to the most urgent communities in Malaysia.

### 2. Frontend

**2.1 Technology: Flutter (Dart)**
KitaCare AI is built entirely with Flutter, a cross-platform UI framework developed by Google. The single codebase runs natively on Android, iOS, and Web from one shared Dart codebase.

**2.2 Application Entry Point & Initialization**
The `main()` function in `main.dart` initializes the application in the following sequence:
*   Loads environment variables (API keys) using `flutter_dotenv` from a `.env` file.
*   Initializes Firebase using `FirebaseOptions` from `firebase_options.dart`, which auto-selects the correct config (Android, iOS, Web, Windows, macOS) based on the platform at runtime.
*   Launches the `KitaCareApp` `MaterialApp`, which immediately routes the user to the `AuthWrapper`.

**2.3 Role-Based Routing & Authentication UI**
The `AuthWrapper` is the app's authentication gateway. It presents three flows depending on user state:
*   **Role Selection Screen:** Users must first choose their account type — Individual Donor, Malaysian NGO, or Logistics Courier. Each role has a distinct visual theme (Emerald green for Donor, Blue for NGO, Orange for Courier).
*   **Login Screen:** After role selection, users log in with email and password. On login, the app fetches the user's stored role from Firestore and compares it against the selected UI role. A role mismatch immediately triggers `FirebaseAuth.signOut()` and displays an 'Access Denied' error.
*   **Signup Screen:** New users complete registration. Their name, email, role, wallet balance (0.0), impactValue (0.0), and livesTouched (0) are written to the Firestore `users` collection upon successful account creation.

**2.4 AppShell & Role-Conditional Navigation**
After authentication, the user enters the `AppShell`, which renders a role-specific bottom navigation bar and page set. Donors see: Dashboard, Relief Map, AI Advisor, My Impact. NGOs see: Mission Hub (NGO Dashboard), Relief Map, AI Advisor, Logistics Data. Couriers see a dedicated Courier Dashboard. The `AppShell` uses Flutter's built-in `Navigator` and `setState` for tab switching, along with a shared `ScrollController` passed to the Donor Dashboard to allow the Relief Map to programmatically scroll the donor to the wallet top-up section.

**2.5 Key Screens & Widgets**

| Screen / Widget | Role | Responsibility |
|---|---|---|
| **DonorDashboard** | Donor | Shows wallet balance, active donation tracking cards with QR codes, impact stats, and top-up flow. Uses StreamBuilders on Firestore for real-time updates. |
| **NGOOperationalDashboard** | NGO | Shows live urgency scores from `relief_cache`, funds summary via `collectionGroup` queries, inventory needed grid, and receipt verification. |
| **CourierDashboard** | Courier | Manages QR code scanning (camera + manual), processes package pickups/deliveries, and updates milestone status in Firestore. |
| **ReliefMap** | Donor & NGO | Interactive map using `SfMaps` with dynamic markers, category filters, and contribution dialogs. Syncs data from the AI-generated `relief_cache`. |
| **AiAdvisorPage** | Donor & NGO | Role-aware Gemini chatbot. Donor-mode helps with finding NGOs and tracking; NGO-mode assists with logistics and field reports. |
| **MyImpactPage** | Donor | Donation audit table with PDF certificate generation using the `pdf` and `open_filex` packages. Shows philanthropy tier based on total `impactValue`. |
| **NGOSecureConsole** | NGO | PIN-based security gate that must be passed before NGO dashboard access is granted. |
| **ProfileScreen** | All | Editable user profile with address, wallet management, and logout. |

**2.6 Third-Party Flutter Packages**

| Package | Purpose |
|---|---|
| **syncfusion_flutter_maps** | Renders the interactive Malaysia relief heatmap with tap-able markers and zoom/pan behavior. |
| **google_generative_ai** | Official Dart SDK for calling the Gemini API directly from the Flutter app. |
| **flutter_dotenv** | Loads `GEMINI_KEY` and `GEMINI_ADVISOR_KEY` from `.env` file at runtime to avoid hardcoding secrets. |
| **firebase_core** / **auth** / **firestore** | Firebase initialization, user authentication, and real-time NoSQL database access. |
| **image_picker** | Allows users and NGOs to capture or upload images as part of item donation flows. |
| **mobile_scanner** | Camera-based QR code scanner used by the Logistics Courier to scan package QR codes. |
| **pdf** / **path_provider** / **open_filex** | Generates and opens PDF donation certificates locally on-device. |
| **share_plus** / **url_launcher** | Sharing donation records and launching external URLs. |
| **google_fonts** / **lucide_icons** | UI consistency — Inter typeface and icon library. |
| **intl** / **xml** | Date formatting and XML parsing utilities. |
| **http** | HTTP client for potential future REST API calls. |

### 3. Backend

**3.1 Architecture Model: Serverless / BaaS**
KitaCare AI uses a fully serverless backend powered by Google Firebase. There is no separate server or custom API. All backend logic runs either within the Flutter app (client-side business logic) or is handled by Firebase's managed services.

**3.2 Firebase Authentication**
Firebase Authentication handles all user identity management. It is responsible for:
*   Creating new user accounts with email and password (`createUserWithEmailAndPassword`).
*   Authenticating existing users (`signInWithEmailAndPassword`).
*   Maintaining session state across app restarts.
*   Enforcing role-based access: upon login, the app retrieves the user's role from Firestore and compares it to the selected UI role. If they do not match, `signOut()` is called immediately, blocking unauthorized access.

**3.3 Business Logic (Client-Side Dart)**
The following key business logic operations are executed in Dart on the client:
*   **Impact Crediting (`creditImpactIfMilestonesComplete`):** A global function triggered after each milestone update. It checks if all milestones on a donation are marked done, calculates `impactValue` and `livesTouched` (RM 10 per life for monetary donations; 2 lives + RM 50 value per physical item), then uses a Firestore transaction to atomically update the user's stats and mark the donation as `isCredited = true` to prevent double-counting.
*   **AI Data Sync (`_syncReliefData`):** On Relief Map load, checks Firestore for a cached result younger than 30 minutes. If fresh, uses it directly. If stale, calls Gemini to regenerate, merges new AI data with any manually submitted NGO entries (`isManual == true`), and saves the merged result back to Firestore.
*   **Smart Merge (`_mergeItemsIntoTarget`):** Prevents duplicate items when merging NGO-submitted needs with AI-generated needs for the same disaster zone.
*   **Donation Flow:** Multi-step dialog for money (wallet deduction + Firestore write + QR code generation via `api.qrserver.com`) and item donations (category/item selection + courier matching + milestone creation).

### 4. Data Storage / Database

**4.1 Technology: Cloud Firestore (Firebase)**
Cloud Firestore is the primary NoSQL database. It stores all structured application data and enables real-time listeners via `StreamBuilder` widgets throughout the app.

**4.2 Data Model**

| Collection / Path | Key Fields | Used By |
|---|---|---|
| `users/{uid}` | name, email, role, walletBalance, impactValue, livesTouched, address | Auth, Dashboard, Impact tracking |
| `users/{uid}/donations/{id}` | type (money/item), amount, quantity, itemName, target, ngo, status, milestones[], qrCodeData, isCredited, timestamp | Donor tracking, Courier scanning, NGO receipt verification |
| `users/{uid}/wallet/{id}` | bankName | Donor funding source selection |
| `needs/{id}` | ngoId, locationName, description, urgency, type (Physical/Field), lat, lng, createdAt | NGO field reports, map overlays |
| `relief_cache/current_status` | results[] (AI-generated zones with location, score, lat, lng, severities, needed_items), timestamp | Relief Map, NGO inventory dashboard |
| `notifications/{uid}/{id}` | title, body, timestamp, type | Notification bell (NGO & Donor) |

**4.3 Real-Time Synchronization**
Firestore's real-time listeners (via `StreamBuilder`) are used extensively across the app. Donor dashboards stream their active `donations` sub-collection. The NGO funds summary streams a `collectionGroup` query across all users' donations to aggregate total monetary intake in real time. The NGO operational dashboard streams the `relief_cache` document to instantly reflect new urgency data.

**4.4 Firestore Transactions**
The impact crediting logic uses `FirebaseFirestore.instance.runTransaction()` to ensure atomicity. This guarantees that a user's `impactValue` and `livesTouched` counters are incremented exactly once per fully completed donation, even if multiple devices trigger the function simultaneously.

### 5. AI Technology Used (Google AI — Gemini)

**5.1 Model Used**
KitaCare AI uses Google Gemini (specifically the `gemini-flash-latest` model variant) accessed via the official `google_generative_ai` Dart SDK. API keys are loaded from a `.env` file at runtime using `flutter_dotenv` (`GEMINI_KEY` for the map and `GEMINI_ADVISOR_KEY` for the chatbot).

**5.2 Use Case 1: AI Relief Map Data Generation**
The core AI feature is the dynamic disaster intelligence layer powering the Relief Map.
How it works:
*   On app load (or when the cache is older than 30 minutes), the `ReliefMap` widget calls `_fetchNewDataFromAI()`.
*   A structured prompt is sent to Gemini requesting active disaster situations in Malaysia within the last 48 hours, organized across five categories (Education, Clothing, Food, Medical, Disaster Relief).
*   The prompt instructs Gemini to return raw JSON only — a list of disaster zone objects, each containing: location name, category, description, urgency score (0-100), GPS coordinates (lat/lng), per-category severity levels (Critical/High/Medium), and 3 specific needed items per category.
*   The raw response is cleaned (markdown fences stripped), parsed with `jsonDecode()`, and merged with any existing NGO-submitted manual entries to prevent data loss.
*   The merged result is written to the Firestore `relief_cache/current_status` document with a server timestamp.
*   If the AI call fails (quota exceeded, network error), the app gracefully falls back to the last cached Firestore data.

**5.3 Use Case 2: AI Donor Advisor Chatbot**
The `AiAdvisorPage` provides a role-aware conversational AI assistant.
*   **Donor mode:** The system prompt instructs Gemini to act as a humanitarian advisor helping Malaysian donors find verified NGOs, understand wallet donations, and track physical contributions.
*   **NGO mode:** The system prompt instructs Gemini to assist NGO staff with disaster relief logistics, QR code verification, inventory management, and field report generation.
*   Each message appends the user's query to a role-specific prompt and calls `model.generateContent([Content.text(prompt)])`. The response text is stripped of markdown asterisks before display.

**5.4 AI-Driven Urgency Scoring & NGO Inventory**
The urgency scores returned by Gemini in the `relief_cache` directly drive the NGO operational dashboard's sortable inventory grid. The frontend logic reads the `severities` field from the AI output to rank needed items (Critical > High > Medium) and display color-coded urgency badges. This means NGO staff see AI-prioritized supply lists without any additional processing step.

### 6. Other Google Technologies and Services Used

| Technology | How It Is Used |
|---|---|
| **Google Firebase (Core)** | Platform backbone — used for app initialization across all 5 supported platforms (Android, iOS, Web, macOS, Windows) via the auto-generated `firebase_options.dart`. |
| **Firebase Authentication** | Manages user signup, login, session persistence, and role-based access enforcement. |
| **Cloud Firestore** | Primary NoSQL database for all structured data including users, donations, needs, relief cache, wallet, and notifications. Powers all real-time `StreamBuilder` widgets. |
| **Firebase Storage (Configured)** | Firebase project is configured with a `storageBucket` (`silentsignalai-87900.firebasestorage.app`) for future file/image uploads from donors and NGOs. |
| **Google Fonts (Inter)** | Typography system used throughout the app via the `google_fonts` Flutter package for consistent, professional UI text rendering. |
| **Gemini API (Flash)** | Core AI engine — powers both the relief map intelligence and the dual-role AI chatbot advisor. |

### 7. Solution Flow

**7.1 Donor Donation Flow**
The following describes the complete end-to-end journey when a donor makes a contribution:
*   **Step 1 — Authentication:** Donor selects 'Individual Donor' role and logs in. Firebase Auth verifies credentials; Firestore role check confirms donor identity.
*   **Step 2 — Relief Map:** Donor opens the map tab. The app checks Firestore for a fresh AI cache. If stale, Gemini generates updated disaster zone data, which is merged and cached in Firestore.
*   **Step 3 — Contribute:** Donor taps a disaster zone card, selects 'Donate Money' or 'Donate Items', and proceeds through the contribution dialog.
*   **Step 4a (Money):** Donor selects a funding source from their `wallet` subcollection, enters an amount, and confirms. The wallet balance is decremented in Firestore, a donation record is written to `users/{uid}/donations` with a QR code URL, and milestones are created.
*   **Step 4b (Items):** Donor selects a category and item from the AI-generated `needed_items` list, chooses self-delivery or courier pick-up, and confirms. A donation record with `type='item'`, `qrCodeData`, and logistics milestones is saved to Firestore.
*   **Step 5 — Tracking:** On the Donor Dashboard, a `StreamBuilder` renders all active donation records with their milestone status. The donor can view their QR code for physical items.
*   **Step 6 — Courier Scan:** A courier scans the item QR code using the `mobile_scanner` camera. The app queries `collectionGroup('donations')` for the matching `qrCodeData`, then updates the appropriate milestone (Picked Up / Arrived at Hub) in Firestore.
*   **Step 7 — NGO Receipt:** The NGO verifies the receipt ID, marks the final delivery milestone as done, and confirms receipt in Firestore.
*   **Step 8 — Impact Credit:** With all milestones complete, `creditImpactIfMilestonesComplete()` runs. A Firestore transaction atomically increments the donor's `impactValue` and `livesTouched` and marks the donation `isCredited = true`.
*   **Step 9 — Certificate:** The donor can view their donation history in `MyImpactPage` and download a PDF certificate generated locally using the `pdf` package.

**7.2 NGO Field Reporting Flow**
*   NGO authenticates and passes the PIN-secured `NGOSecureConsole` gate.
*   From the Mission Hub, NGO submits a new field report (district, crisis summary, urgency) or physical goods request via the 'Publish to Map' sheet. This writes a new document to the `needs` Firestore collection.
*   The submission is tagged with `isManual = true` or detected via the 'NGO REPORT:' prefix in the `description` field.
*   On the next AI refresh cycle, the smart merge function (`_mergeItemsIntoTarget`) preserves these manual entries alongside newly generated AI zones, ensuring NGO data is never overwritten.
*   NGOs can also access real-time analytics: total donated funds (aggregated via `collectionGroup` query), incoming donation trends, and AI-sorted inventory lists.

### 8. Other Technical Tools

| Tool / Service | Purpose |
|---|---|
| **api.qrserver.com (External REST API)** | Generates QR code images for physical item donations. The app constructs a URL (`https://api.qrserver.com/v1/create-qr-code/?size=150x150&data={qrData}`) and renders it via `Image.network()` — no backend required. |
| **Unsplash & Pexels (CDN)** | Disaster zone category images displayed on donation cards are loaded from Unsplash/Pexels CDN URLs, categorized by type (Food, Medical, Clothing, etc.). |
| **flutter_dotenv (.env)** | Secrets management — `GEMINI_KEY` and `GEMINI_ADVISOR_KEY` are stored outside source code and loaded at startup, preventing key exposure in version control. |
| **FlutterFire CLI** | Used during setup to auto-generate `firebase_options.dart`, which contains platform-specific Firebase configuration for all 5 supported platforms. |
| **pdf (Dart package)** | On-device PDF generation for donation certificates — no server call required. Generated files are opened directly using `open_filex`. |
| **syncfusion_flutter_maps** | The `SfMaps` widget renders Malaysia's geographic map from local GeoJSON/tile data, with custom markers for each AI-identified disaster zone and interactive tap-to-zoom behavior. |

---

## 💡 Innovation & Technical Challenges Faced

**The Challenge: Merging AI Data with Human Data**
One of the most significant technical challenges we faced was successfully merging automated AI data with human-verified data. The app features a live relief map that uses Gemini AI to scan news and plot active disaster zones. Simultaneously, NGOs use the app to manually request very specific, critical items for those exact zones. Because the AI generates a completely new JSON list of disaster zones every time it runs, saving this fresh data to Firestore would accidentally overwrite and delete all the custom, life-saving items the NGOs had painstakingly entered. 

Furthermore, if multiple users opened the app simultaneously, it triggered dozens of simultaneous AI requests, leading to API rate limits and slow loading times.

**Our Innovative Solutions:**
1.  **Smart Caching & Concurrency Locks:** To solve performance and rate limits, we engineered a smart caching system in Firestore. Instead of pinging the AI constantly, the app checks the cache timestamp. If the data is less than 30 minutes old, it instantly loads the saved data. If an update is required, the app engages a software lock so that only the *first* user triggers the AI fetch, while others wait a moment for the updated result. This drastically reduced API costs and prevented crashes.
2.  **The "Deep-Merge" Algorithm:** To prevent the AI from deleting NGO data, we wrote a custom deep-merge algorithm in Dart. When the AI returns a fresh list of disaster zones, our algorithm pauses before saving. It queries the old database records, searches for any items flagged as `isManual` (human-entered), and carefully weaves those specific items directly into the newly generated AI payload. This results in a highly resilient system that leverages the autonomous speed of AI while perfectly preserving the critical details provided by human relief workers on the ground.

---

## ⚙️ Setup & Installation Instructions

**1. Prerequisites**
*   Flutter SDK installed.
*   Android Studio with an Android Emulator (Recommended for testing).

**2. Environment Setup**
To run this app locally, you will need your own API keys from Google AI Studio and Firebase. 

Create a `.env` file in the root directory of the project and add your API keys like this:

`GEMINI_KEY=your_gemini_api_key_here`
`GEMINI_ADVISOR_KEY=your_gemini_advisor_key_here`
`FIREBASE_KEY=your_firebase_api_key_here`
`GEMINI_FIND_KEY=your_gemini_find_key_here `

**3. Run the App**
```bash
flutter clean
flutter pub get
flutter run