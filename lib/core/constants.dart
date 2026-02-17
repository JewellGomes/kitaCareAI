import 'package:flutter/material.dart';

// ============================================================
// API CONFIGURATION
// ============================================================

/// [BACKEND]: Replace with environment variable or secure storage.
/// Never hardcode API keys in production — use flutter_dotenv or similar.
const String kGeminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';

const String kGeminiModel = 'gemini-1.5-flash';

// ============================================================
// APP COLORS
// ============================================================

class AppColors {
  AppColors._();

  static const emerald600 = Color(0xFF059669);
  static const emerald50  = Color(0xFFECFDF5);
  static const emerald100 = Color(0xFFD1FAE5);
  static const emerald900 = Color(0xFF064E3B);

  static const blue600   = Color(0xFF2563EB);
  static const blue50    = Color(0xFFEFF6FF);
  static const blue100   = Color(0xFFDBEAFE);

  static const slate50   = Color(0xFFF8FAFC);
  static const slate100  = Color(0xFFF1F5F9);
  static const slate200  = Color(0xFFE2E8F0);
  static const slate300  = Color(0xFFCBD5E1);
  static const slate400  = Color(0xFF94A3B8);
  static const slate500  = Color(0xFF64748B);
  static const slate600  = Color(0xFF475569);
  static const slate700  = Color(0xFF334155);
  static const slate800  = Color(0xFF1E293B);
  static const slate900  = Color(0xFF0F172A);

  static const red500    = Color(0xFFEF4444);
  static const red50     = Color(0xFFFEF2F2);
  static const red600    = Color(0xFFDC2626);
}

// ============================================================
// ITEM CATEGORIES
// ============================================================

class ItemCategory {
  final String id;
  final String name;
  final IconData icon;
  final List<String> items;
  final String demand; // 'Critical' | 'High' | 'Medium'

  const ItemCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.items,
    required this.demand,
  });
}

const List<ItemCategory> kItemCategories = [
  ItemCategory(
    id: 'edu',
    name: 'Education',
    icon: Icons.book_outlined,
    items: ['Books', 'Stationery', 'School Bags'],
    demand: 'Medium',
  ),
  ItemCategory(
    id: 'clo',
    name: 'Clothing',
    icon: Icons.checkroom_outlined,
    items: ['Children Clothes', 'Adult Basics', 'Raincoats'],
    demand: 'High',
  ),
  ItemCategory(
    id: 'foo',
    name: 'Food',
    icon: Icons.shopping_bag_outlined,
    items: ['Dry Food (Rice/Flour)', 'Baby Formula', 'Canned Goods'],
    demand: 'Critical',
  ),
  ItemCategory(
    id: 'med',
    name: 'Medical',
    icon: Icons.medical_services_outlined,
    items: ['First-Aid Kits', 'Sanitary Pads', 'Adult Diapers'],
    demand: 'High',
  ),
  ItemCategory(
    id: 'dis',
    name: 'Disaster Relief',
    icon: Icons.thunderstorm_outlined,
    items: ['Blankets', 'Emergency Tents', 'Flashlights'],
    demand: 'Medium',
  ),
];

// ============================================================
// MOCK DATA
// ============================================================

/// [BACKEND]: Replace with GET /api/needs — from crisis tracking / NGO submissions service.
final List<Map<String, dynamic>> kMockNeeds = [
  {
    'id': 1,
    'location': 'Rantau Panjang, Kelantan',
    'category': 'Flood Relief',
    'score': 92,
    'description':
        'Rising water levels. Immediate need for clean water and sanitary kits for 200 displaced families.',
    'verifiedBy': 'MERCY Malaysia',
    'coordinates': '6.0028, 101.9750',
    'bank': {
      'name': 'Maybank',
      'account': '5140-XXXX-2241',
      'holder': 'MERCY Malaysia Relief Fund',
    },
    'physicalNeeds': ['Rice', 'Blankets', 'Hygiene Kits'],
  },
  {
    'id': 2,
    'location': 'Baling, Kedah',
    'category': 'Food Security',
    'score': 78,
    'description':
        'Flash flood recovery. 50 households requiring dry food rations and school supplies.',
    'verifiedBy': 'MyCARE',
    'coordinates': '5.6766, 100.9167',
    'bank': {
      'name': 'CIMB Bank',
      'account': '8008-XXXX-9912',
      'holder': 'MyCARE Humanitarian Fund',
    },
    'physicalNeeds': ['School Bags', 'Stationery'],
  },
  {
    'id': 3,
    'location': 'Keningau, Sabah',
    'category': 'Medical Aid',
    'score': 65,
    'description':
        'Remote community clinics requiring essential medicine and cooling storage for vaccines.',
    'verifiedBy': 'PERTIWI',
    'coordinates': '5.3333, 116.1667',
    'bank': {
      'name': 'Public Bank',
      'account': '3211-XXXX-4451',
      'holder': 'PERTIWI Soup Kitchen',
    },
    'physicalNeeds': ['First-Aid Kits', 'Thermometers'],
  },
];

/// [BACKEND]: Replace with GET /api/donations — from donation management service.
final List<Map<String, dynamic>> kInitialDonations = [
  {
    'id': 'KC-88421',
    'donor': 'Ahmad',
    'amount': 150,
    'type': 'money',
    'target': 'Kelantan Flood Relief',
    'ngo': 'MERCY Malaysia',
    'status': 'In Transit',
    'date': '2024-10-24',
    'category': 'Flood Relief',
    'milestones': [
      {'label': 'Donation Received',   'date': '2024-10-24 09:00', 'done': true},
      {'label': 'Items Procured',      'date': '2024-10-25 14:30', 'done': true,  'detail': '10kg Rice, 2x Hygiene Kits'},
      {'label': 'Lorry Dispatched',    'date': '2024-10-26 08:00', 'done': true,  'detail': 'Plate No: VAB 4421'},
      {'label': 'Distribution at Site','date': 'Est. Oct 27',      'done': false, 'detail': 'Rantau Panjang Primary School'},
    ],
    'evidence':
        'https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?auto=format&fit=crop&q=80&w=400',
  },
  {
    'id': 'KC-ITEM-001',
    'donor': 'Ahmad',
    'amount': 0,
    'type': 'item',
    'itemDetails': '10x Secondary School Books',
    'target': 'Keningau Learning Center',
    'ngo': 'PERTIWI',
    'status': 'Received',
    'date': '2024-10-28',
    'category': 'Education',
    'milestones': [],
    'evidence':
        'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?auto=format&fit=crop&q=80&w=400',
  },
];

/// [BACKEND]: Replace with GET /api/drop-off-points — from location/logistics database.
const List<Map<String, String>> kDropOffPoints = [
  {
    'id': '1',
    'name': 'MERCY Malaysia HQ',
    'address': 'Kuala Lumpur City Centre',
    'hours': '9AM - 5PM',
    'condition': 'New/Gently Used',
  },
  {
    'id': '2',
    'name': 'St. John Ambulance Point',
    'address': 'Petaling Jaya, Selangor',
    'hours': '8AM - 8PM',
    'condition': 'New Only',
  },
  {
    'id': '3',
    'name': 'Community Library',
    'address': 'Keningau Town, Sabah',
    'hours': '10AM - 6PM',
    'condition': 'Books/Stationery',
  },
];