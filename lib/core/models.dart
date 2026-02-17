// ============================================================
// DATA MODELS
// ============================================================

/// Roles a user can have in the app.
enum UserRole { donor, ngo }

/// A single step in a donation's journey.
class DonationMilestone {
  final String label;
  final String date;
  final bool done;
  final String? detail;

  const DonationMilestone({
    required this.label,
    required this.date,
    required this.done,
    this.detail,
  });

  factory DonationMilestone.fromMap(Map<String, dynamic> m) {
    return DonationMilestone(
      label:  m['label'] as String,
      date:   m['date'] as String,
      done:   m['done'] as bool,
      detail: m['detail'] as String?,
    );
  }
}

/// A user's donation record (money or physical item).
class Donation {
  final String id;
  final String donor;
  final double amount;
  final String type; // 'money' | 'item'
  final String? itemDetails;
  final String target;
  final String ngo;
  final String status;
  final String date;
  final String category;
  final List<DonationMilestone> milestones;
  final String evidence;

  const Donation({
    required this.id,
    required this.donor,
    required this.amount,
    required this.type,
    this.itemDetails,
    required this.target,
    required this.ngo,
    required this.status,
    required this.date,
    required this.category,
    required this.milestones,
    required this.evidence,
  });

  factory Donation.fromMap(Map<String, dynamic> m) {
    final rawMilestones = (m['milestones'] as List?)
        ?.map((e) => DonationMilestone.fromMap(e as Map<String, dynamic>))
        .toList() ?? [];

    return Donation(
      id:          m['id'] as String,
      donor:       m['donor'] as String,
      amount:      (m['amount'] as num).toDouble(),
      type:        m['type'] as String,
      itemDetails: m['itemDetails'] as String?,
      target:      m['target'] as String,
      ngo:         m['ngo'] as String,
      status:      m['status'] as String,
      date:        m['date'] as String,
      category:    m['category'] as String,
      milestones:  rawMilestones,
      evidence:    m['evidence'] as String,
    );
  }
}

/// A humanitarian need registered by an NGO.
class HumanitarianNeed {
  final int id;
  final String location;
  final String category;
  final int score;          // 0–100 urgency score
  final String description;
  final String verifiedBy;
  final String coordinates;
  final BankInfo bank;
  final List<String> physicalNeeds;

  const HumanitarianNeed({
    required this.id,
    required this.location,
    required this.category,
    required this.score,
    required this.description,
    required this.verifiedBy,
    required this.coordinates,
    required this.bank,
    required this.physicalNeeds,
  });

  factory HumanitarianNeed.fromMap(Map<String, dynamic> m) {
    return HumanitarianNeed(
      id:            m['id'] as int,
      location:      m['location'] as String,
      category:      m['category'] as String,
      score:         m['score'] as int,
      description:   m['description'] as String,
      verifiedBy:    m['verifiedBy'] as String,
      coordinates:   m['coordinates'] as String,
      bank:          BankInfo.fromMap(m['bank'] as Map<String, dynamic>),
      physicalNeeds: List<String>.from(m['physicalNeeds'] as List),
    );
  }
}

/// Bank account details for an NGO's donation target.
class BankInfo {
  final String name;
  final String account;
  final String holder;

  const BankInfo({
    required this.name,
    required this.account,
    required this.holder,
  });

  factory BankInfo.fromMap(Map<String, dynamic> m) {
    return BankInfo(
      name:    m['name'] as String,
      account: m['account'] as String,
      holder:  m['holder'] as String,
    );
  }
}

/// A physical drop-off location for donated items.
class DropOffPoint {
  final String id;
  final String name;
  final String address;
  final String hours;
  final String condition;

  const DropOffPoint({
    required this.id,
    required this.name,
    required this.address,
    required this.hours,
    required this.condition,
  });

  factory DropOffPoint.fromMap(Map<String, String> m) {
    return DropOffPoint(
      id:        m['id']!,
      name:      m['name']!,
      address:   m['address']!,
      hours:     m['hours']!,
      condition: m['condition']!,
    );
  }
}

/// Result from the AI item-matching service.
class AiMatchResult {
  final String community;
  final String ngo;
  final String priority;
  final DropOffPoint dropOff;

  const AiMatchResult({
    required this.community,
    required this.ngo,
    required this.priority,
    required this.dropOff,
  });
}

/// A chat message between user and AI advisor.
class ChatMessage {
  final String role; // 'user' | 'ai'
  final String content;

  const ChatMessage({required this.role, required this.content});
}

/// A saved payment method in the donor's wallet.
class PaymentMethod {
  final String id;
  final String bank;
  final String account;

  const PaymentMethod({
    required this.id,
    required this.bank,
    required this.account,
  });
}