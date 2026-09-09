import 'money.dart';

/// How the merchant contacted the customer (spec §8.8).
enum ContactMethod { phone, visit, message, other }

/// Outcome of a collection contact (spec §8.8).
enum CollectionStatus {
  notContacted,
  contacted,
  promiseToPay,
  partiallyPaid,
  paid,
  refusedDisputed,
  followUpRequired,
}

/// State of a promise to pay (spec §8.9).
enum PromiseStatus { open, fulfilled, partial, broken }

/// A collection contact logged against a customer.
class CollectionActivity {
  final String id;
  final String customerId;
  final ContactMethod method;
  final CollectionStatus status;
  final String? note;
  final DateTime contactedAt;
  final DateTime? nextFollowUp;

  const CollectionActivity({
    required this.id,
    required this.customerId,
    required this.method,
    required this.status,
    required this.contactedAt,
    this.note,
    this.nextFollowUp,
  });
}

/// A customer's promise to pay a given amount by a date.
class PromiseToPay {
  final String id;
  final String customerId;
  final Money promisedAmount;
  final DateTime promiseDate;
  final DateTime? followUpDate;
  final String? customerNote;
  final PromiseStatus status;
  final DateTime createdAt;

  const PromiseToPay({
    required this.id,
    required this.customerId,
    required this.promisedAmount,
    required this.promiseDate,
    required this.createdAt,
    this.followUpDate,
    this.customerNote,
    this.status = PromiseStatus.open,
  });
}

// ---- enum <-> storage code (must match the PostgreSQL enums) ----

const Map<ContactMethod, String> contactMethodCodes = {
  ContactMethod.phone: 'phone',
  ContactMethod.visit: 'visit',
  ContactMethod.message: 'message',
  ContactMethod.other: 'other',
};

const Map<CollectionStatus, String> collectionStatusCodes = {
  CollectionStatus.notContacted: 'not_contacted',
  CollectionStatus.contacted: 'contacted',
  CollectionStatus.promiseToPay: 'promise_to_pay',
  CollectionStatus.partiallyPaid: 'partially_paid',
  CollectionStatus.paid: 'paid',
  CollectionStatus.refusedDisputed: 'refused_disputed',
  CollectionStatus.followUpRequired: 'follow_up_required',
};

const Map<PromiseStatus, String> promiseStatusCodes = {
  PromiseStatus.open: 'open',
  PromiseStatus.fulfilled: 'fulfilled',
  PromiseStatus.partial: 'partial',
  PromiseStatus.broken: 'broken',
};

ContactMethod contactMethodFromCode(String code) =>
    contactMethodCodes.entries.firstWhere((e) => e.value == code).key;
CollectionStatus collectionStatusFromCode(String code) =>
    collectionStatusCodes.entries.firstWhere((e) => e.value == code).key;
PromiseStatus promiseStatusFromCode(String code) =>
    promiseStatusCodes.entries.firstWhere((e) => e.value == code).key;
