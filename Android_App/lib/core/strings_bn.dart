/// Bangla UI strings, in one place (Coding Standards §5 — no hard-coded strings
/// in widgets; English is a later secondary language). Bangla-first (spec §33).
class S {
  static const appName = 'বাকিবন্ধু';

  // Home
  static const totalOwedLabel = 'মোট বাকি — আপনার পাওনা';
  static const newCustomer = 'নতুন কাস্টমার';
  static const emptyTitle = 'এখনো কোনো কাস্টমার নেই';
  static const emptyPrompt = 'আপনার প্রথম কাস্টমার যোগ করে বাকির হিসাব শুরু করুন।';
  static String customerCount(int n) => '$n জন কাস্টমার';

  // Customer detail
  static const currentDue = 'এখন বাকি';
  static const advance = 'অগ্রিম';
  static const settled = 'পরিশোধিত';
  static const history = 'লেনদেন';
  static const noHistory = 'এখনো কোনো লেনদেন নেই';
  static const gaveCredit = 'বাকি দিলাম';
  static const gotPayment = 'টাকা পেলাম';
  static const remind = 'মনে করান';
  static const reminderSoon = 'রিমাইন্ডার শীঘ্রই যোগ হচ্ছে';

  // Forms
  static const nameLabel = 'নাম';
  static const nameRequired = 'নাম লিখুন';
  static const mobileLabel = 'মোবাইল নম্বর (ঐচ্ছিক)';
  static const amountLabel = 'পরিমাণ';
  static const amountRequired = 'সঠিক পরিমাণ লিখুন';
  static const noteLabel = 'নোট (ঐচ্ছিক)';
  static const save = 'সেভ করুন';
  static const add = 'যোগ করুন';
  static const cancel = 'বাতিল';
}
