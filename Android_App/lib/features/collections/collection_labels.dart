import 'package:bakibondhu/domain/collections.dart';

/// Bangla labels for the collection enums (kept out of the domain layer).

const Map<ContactMethod, String> contactMethodLabels = {
  ContactMethod.phone: 'ফোন',
  ContactMethod.visit: 'সরাসরি',
  ContactMethod.message: 'মেসেজ',
  ContactMethod.other: 'অন্যান্য',
};

const Map<CollectionStatus, String> collectionStatusLabels = {
  CollectionStatus.notContacted: 'যোগাযোগ হয়নি',
  CollectionStatus.contacted: 'যোগাযোগ হয়েছে',
  CollectionStatus.promiseToPay: 'পরিশোধের প্রতিশ্রুতি',
  CollectionStatus.partiallyPaid: 'আংশিক পরিশোধ',
  CollectionStatus.paid: 'পরিশোধিত',
  CollectionStatus.refusedDisputed: 'অস্বীকার / বিরোধ',
  CollectionStatus.followUpRequired: 'ফলো-আপ দরকার',
};

const Map<PromiseStatus, String> promiseStatusLabels = {
  PromiseStatus.open: 'খোলা',
  PromiseStatus.fulfilled: 'পূর্ণ',
  PromiseStatus.partial: 'আংশিক',
  PromiseStatus.broken: 'ভঙ্গ',
};
