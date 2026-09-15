/// Bangla UI strings, in one place (Coding Standards §5 — no hard-coded strings
/// in widgets; English is a later secondary language). Bangla-first (spec §33).
class S {
  static const appName = 'বাকিবন্ধু';

  // Home
  static const totalOwedLabel = 'মোট বাকি — আপনার পাওনা';
  static const totalSales = 'মোট বিক্রি';
  static const todaysSales = 'আজকের বিক্রি';
  static const viewDailySales = 'বিক্রির হিসাব দেখুন';
  static const newCustomer = 'নতুন কাস্টমার';
  static const searchCustomers = 'নাম বা মোবাইল দিয়ে খুঁজুন';
  static String noSearchResults(String q) => '“$q” — এমন কোনো কাস্টমার পাওয়া যায়নি';
  static const sortBy = 'সাজান';
  static const sortMostOwed = 'সর্বোচ্চ বাকি';
  static const sortByName = 'নাম (ক–হ)';
  static const sortRecent = 'নতুন আগে';

  // Trial / subscription reminder (Home banner)
  static const trialDismiss = 'বন্ধ করুন';
  static String trialEndsInDays(int days) => days <= 0
      ? 'আপনার মেয়াদ আজই শেষ হচ্ছে। চালু রাখতে অ্যাডমিনের সাথে যোগাযোগ করুন।'
      : (days == 1
          ? 'আপনার মেয়াদ আগামীকাল শেষ হচ্ছে। চালু রাখতে অ্যাডমিনের সাথে যোগাযোগ করুন।'
          : 'আপনার মেয়াদ শেষ হতে $days দিন বাকি। চালু রাখতে অ্যাডমিনের সাথে যোগাযোগ করুন।');
  static const trialExpired =
      'আপনার মেয়াদ শেষ হয়ে গেছে। সিঙ্ক চালু রাখতে অ্যাডমিনের সাথে যোগাযোগ করুন।';

  // Sales report
  static const salesReportTitle = 'বিক্রির হিসাব';
  static const noSales = 'এখনো কোনো বিক্রি নেই';
  static const yesterday = 'গতকাল';
  static String salesCount(int n) => '$n টি বিক্রি';
  static const addSale = 'বিক্রি যোগ করুন';
  static const saleAmountLabel = 'বিক্রির পরিমাণ (৳)';
  static const saleNoteLabel = 'বিবরণ (ঐচ্ছিক)';
  static const saleSaved = 'বিক্রি যোগ হয়েছে';
  static const periodDaily = 'দৈনিক';
  static const periodMonthly = 'মাসিক';
  static const periodQuarterly = 'ত্রৈমাসিক';
  static const periodYearly = 'বার্ষিক';
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
  static const mobileLabelRequired = 'মোবাইল নম্বর';
  static const mobileRequired = 'মোবাইল নম্বর দিন';
  static const invalidMobile = 'সঠিক মোবাইল নম্বর দিন (১১ সংখ্যা, 01…)';
  static const duplicateCustomerPhone = 'এই মোবাইল নম্বরে একজন কাস্টমার আগে থেকেই আছে';
  static const addressLabelOptional = 'ঠিকানা (ঐচ্ছিক)';
  static const amountLabel = 'পরিমাণ';
  static const amountRequired = 'সঠিক পরিমাণ লিখুন';
  static const noteLabel = 'নোট (ঐচ্ছিক)';
  static const save = 'সেভ করুন';
  static const add = 'যোগ করুন';
  static const cancel = 'বাতিল';
  static const delete = 'মুছুন';

  // Edit / delete customer
  static const editCustomer = 'কাস্টমার এডিট করুন';
  static const deleteCustomer = 'কাস্টমার মুছুন';

  // Transaction history export
  static const exportHistory = 'লেনদেন এক্সপোর্ট করুন';
  static const historyExportTitle = 'লেনদেনের হিসাব';
  static const shopLabel = 'দোকান';
  static const customerLabel = 'কাস্টমার';
  static const runningDue = 'চলতি বাকি';
  static const totalTransactions = 'মোট লেনদেন';
  static const currentBalanceLabel = 'বর্তমান হিসাব';
  static const madeWithApp = 'বাকিবন্ধু অ্যাপ দিয়ে তৈরি';
  static const adjustmentUp = 'সমন্বয় (বৃদ্ধি)';
  static const adjustmentDown = 'সমন্বয় (হ্রাস)';
  static const copyText = 'কপি করুন';
  static const shareText = 'শেয়ার করুন';
  static const copied = 'কপি হয়েছে';
  static const nothingToExport = 'এক্সপোর্ট করার মতো লেনদেন নেই';
  static const customerUpdated = 'কাস্টমারের তথ্য আপডেট হয়েছে';
  static const cannotDeleteHasTxns =
      'এই কাস্টমারের লেনদেন আছে — আগে হিসাব নিষ্পত্তি করুন, তারপর মুছুন।';
  static String deleteCustomerConfirm(String name) =>
      '“$name”-কে মুছে ফেলবেন? এটি আর ফেরানো যাবে না।';

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

  // Sync Center (Screen §5.14)
  static const syncCenter = 'সিঙ্ক';
  static const syncNow = 'এখন সিঙ্ক করুন';
  static const synced = 'সিঙ্ক হয়েছে';
  static const toUpload = 'আপলোডের অপেক্ষায়';
  static const failedLabel = 'ব্যর্থ';
  static const conflictsLabel = 'দ্বন্দ্ব';
  static const allSynced = 'সব সিঙ্ক হয়েছে';
  static const notConnected = 'সার্ভার এখনো যুক্ত হয়নি — সব ডেটা এই ফোনে সংরক্ষিত।';
  static const conflictsNeedReview = 'কিছু লেনদেন পর্যালোচনা দরকার';
  static const conflictReviewSoon = 'সার্ভার যুক্ত হলে দ্বন্দ্ব পর্যালোচনা করা যাবে';
  static String syncResult(int pushed, int pulled) =>
      'আপলোড $pushed · ডাউনলোড $pulled';

  // Collections (§8.8/§8.9)
  static const collections = 'কালেকশন';
  static const recordCollection = 'কালেকশন যোগ করুন';
  static const recordPromise = 'প্রতিশ্রুতি যোগ করুন';
  static const promises = 'প্রতিশ্রুতি';
  static const activityHistory = 'কালেকশন ইতিহাস';
  static const noActivity = 'এখনো কোনো কালেকশন নেই';
  static const noPromises = 'এখনো কোনো প্রতিশ্রুতি নেই';
  static const methodLabel = 'যোগাযোগ';
  static const statusLabel = 'অবস্থা';
  static const nextFollowUpLabel = 'পরবর্তী ফলো-আপ';
  static const promiseAmountLabel = 'প্রতিশ্রুত পরিমাণ';
  static const promiseDateLabel = 'প্রতিশ্রুতির তারিখ';

  // Settings
  static const settings = 'সেটিংস';
  static const shopNameSetting = 'দোকানের নাম';
  static const accountSection = 'সিঙ্ক ও অ্যাকাউন্ট';
  static const aboutSection = 'সম্পর্কে';
  static const savedMsg = 'সংরক্ষিত হয়েছে';
  static const notLoggedIn = 'লগ ইন করা নেই';

  // Auth (login to sync)
  static const logIn = 'লগ ইন';
  static const registerAction = 'নিবন্ধন';
  static const signInToSync = 'সিঙ্ক করতে লগ ইন করুন';
  static const logOut = 'লগ আউট';
  static const passwordLabel = 'পাসওয়ার্ড';
  static const businessNameLabel = 'দোকান/ব্যবসার নাম';
  static const businessRequired = 'দোকান/ব্যবসার নাম দিন';
  static const yourNameLabel = 'আপনার নাম';
  static const identifierLabel = 'মোবাইল নম্বর';
  static const thanaLabel = 'থানা/উপজেলা (ঐচ্ছিক)';
  static const zilaLabel = 'জেলা (ঐচ্ছিক)';
  static const selectZilaHint = 'জেলা নির্বাচন করুন';
  static const selectThanaHint = 'থানা/উপজেলা নির্বাচন করুন';
  static const selectZilaFirst = 'আগে জেলা নির্বাচন করুন';
  static const passwordShort = 'কমপক্ষে ৬ অক্ষরের পাসওয়ার্ড দিন';
  static const toggleToLogin = 'অ্যাকাউন্ট আছে? লগ ইন করুন';
  static const toggleToRegister = 'নতুন? নিবন্ধন করুন';
  static const authFailed = 'ব্যর্থ হয়েছে';
  static String loggedInAs(String role) => 'লগ ইন করা আছে ($role)';

  // Landing (opening screen)
  static const landingTagline = 'বাকির হিসাব সহজে রাখুন — ইন্টারনেট ছাড়াও চলে।';
  static const landingLogin = 'লগ ইন করুন';
  static const landingRegister = 'নতুন অ্যাকাউন্ট খুলুন';
  static const continueOffline = 'অ্যাকাউন্ট ছাড়া চালিয়ে যান';

  // First run / onboarding
  static const welcome = 'স্বাগতম';
  static const onboardSubtitle = 'আপনার দোকানের নাম দিন — রিমাইন্ডারে ব্যবহার হবে।';
  static const shopNameLabel = 'দোকানের নাম (ঐচ্ছিক)';
  static const getStarted = 'শুরু করুন';
}

