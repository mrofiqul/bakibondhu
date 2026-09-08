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

  // Add transaction (Screen 3)
  static const dateLabel = 'তারিখ';
  static const today = 'আজ';
  static const dueDateLabel = 'শেষ তারিখ';

  // Reminder (Screen 5)
  static const reminderTitle = 'মনে করিয়ে দিন';
  static const sendSms = 'SMS পাঠান';
  static const whatsapp = 'WhatsApp';
  static const editBeforeSend = 'পাঠানোর আগে বদলাতে পারেন';
  static const needPhone = 'রিমাইন্ডার পাঠাতে মোবাইল নম্বর দরকার';
  static const nothingDue = 'এই কাস্টমারের কোনো বাকি নেই';
  static const shopNamePlaceholder = 'আপনার দোকান';
  static const couldNotOpen = 'অ্যাপটি খোলা গেল না';
}

