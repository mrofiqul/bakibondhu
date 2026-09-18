/// UI strings for both supported languages. Bangla-first (spec §33) with
/// English as a runtime-switchable secondary language. [S.lang] selects the
/// active language; every member returns the string for it, so call sites stay
/// `S.foo` and the whole app re-renders when the language changes.
enum AppLang { bn, en }

class S {
  static AppLang lang = AppLang.bn;
  static bool get _bn => lang == AppLang.bn;

  /// Language names, always shown in their own script (for the selector).
  static const langBanglaName = 'বাংলা';
  static const langEnglishName = 'English';
  static String get language => _bn ? 'ভাষা' : 'Language';

  static String get appName => _bn ? 'বাকিবন্ধু' : 'BakiBondhu';

  // Home
  static String get totalOwedLabel => _bn ? 'মোট বাকি — আপনার পাওনা' : 'Total due — your receivables';
  static String get totalSales => _bn ? 'মোট বিক্রি' : 'Total sales';
  static String get todaysSales => _bn ? 'আজকের বিক্রি' : "Today's sales";
  static String get viewDailySales => _bn ? 'বিক্রির হিসাব দেখুন' : 'View sales report';
  static String get newCustomer => _bn ? 'নতুন কাস্টমার' : 'New customer';
  static String get searchCustomers => _bn ? 'নাম বা মোবাইল দিয়ে খুঁজুন' : 'Search by name or mobile';
  static String noSearchResults(String q) => _bn ? '“$q” — এমন কোনো কাস্টমার পাওয়া যায়নি' : '“$q” — no matching customer found';
  static String get sortBy => _bn ? 'সাজান' : 'Sort';
  static String get sortMostOwed => _bn ? 'সর্বোচ্চ বাকি' : 'Most owed';
  static String get sortByName => _bn ? 'নাম (ক–হ)' : 'Name (A–Z)';
  static String get sortRecent => _bn ? 'নতুন আগে' : 'Newest first';

  // Trial / subscription reminder (Home banner)
  static String get trialDismiss => _bn ? 'বন্ধ করুন' : 'Dismiss';
  static String trialEndsInDays(int days) => _bn
      ? (days <= 0
          ? 'আপনার মেয়াদ আজই শেষ হচ্ছে। চালু রাখতে অ্যাডমিনের সাথে যোগাযোগ করুন।'
          : (days == 1
              ? 'আপনার মেয়াদ আগামীকাল শেষ হচ্ছে। চালু রাখতে অ্যাডমিনের সাথে যোগাযোগ করুন।'
              : 'আপনার মেয়াদ শেষ হতে $days দিন বাকি। চালু রাখতে অ্যাডমিনের সাথে যোগাযোগ করুন।'))
      : (days <= 0
          ? 'Your subscription ends today. Contact the admin to keep it active.'
          : (days == 1
              ? 'Your subscription ends tomorrow. Contact the admin to keep it active.'
              : 'Your subscription ends in $days days. Contact the admin to keep it active.'));
  static String get trialExpired => _bn
      ? 'আপনার মেয়াদ শেষ হয়ে গেছে। সিঙ্ক চালু রাখতে অ্যাডমিনের সাথে যোগাযোগ করুন।'
      : 'Your subscription has expired. Contact the admin to keep sync active.';

  // Sales report
  static String get salesReportTitle => _bn ? 'বিক্রির হিসাব' : 'Sales report';
  static String get noSales => _bn ? 'এখনো কোনো বিক্রি নেই' : 'No sales yet';
  static String get yesterday => _bn ? 'গতকাল' : 'Yesterday';
  static String salesCount(int n) => _bn ? '$n টি বিক্রি' : '$n sales';
  static String get addSale => _bn ? 'বিক্রি যোগ করুন' : 'Add sale';
  static String get saleAmountLabel => _bn ? 'বিক্রির পরিমাণ (৳)' : 'Sale amount (৳)';
  static String get saleNoteLabel => _bn ? 'বিবরণ (ঐচ্ছিক)' : 'Note (optional)';
  static String get saleSaved => _bn ? 'বিক্রি যোগ হয়েছে' : 'Sale added';
  static String get periodDaily => _bn ? 'দৈনিক' : 'Daily';
  static String get periodMonthly => _bn ? 'মাসিক' : 'Monthly';
  static String get periodQuarterly => _bn ? 'ত্রৈমাসিক' : 'Quarterly';
  static String get periodYearly => _bn ? 'বার্ষিক' : 'Yearly';
  static String get emptyTitle => _bn ? 'এখনো কোনো কাস্টমার নেই' : 'No customers yet';
  static String get emptyPrompt => _bn ? 'আপনার প্রথম কাস্টমার যোগ করে বাকির হিসাব শুরু করুন।' : 'Add your first customer to start tracking dues.';
  static String customerCount(int n) => _bn ? '$n জন কাস্টমার' : '$n customers';

  // Customer detail
  static String get currentDue => _bn ? 'এখন বাকি' : 'Due now';
  static String get advance => _bn ? 'অগ্রিম' : 'Advance';
  static String get settled => _bn ? 'পরিশোধিত' : 'Settled';
  static String get history => _bn ? 'লেনদেন' : 'Transactions';
  static String get noHistory => _bn ? 'এখনো কোনো লেনদেন নেই' : 'No transactions yet';
  static String get gaveCredit => _bn ? 'বাকি দিলাম' : 'Gave credit';
  static String get gotPayment => _bn ? 'টাকা পেলাম' : 'Got payment';
  static String get remind => _bn ? 'মনে করান' : 'Remind';
  static String get reminderSoon => _bn ? 'রিমাইন্ডার শীঘ্রই যোগ হচ্ছে' : 'Reminder coming soon';

  // Forms
  static String get nameLabel => _bn ? 'নাম' : 'Name';
  static String get nameRequired => _bn ? 'নাম লিখুন' : 'Enter a name';
  static String get mobileLabel => _bn ? 'মোবাইল নম্বর (ঐচ্ছিক)' : 'Mobile number (optional)';
  static String get mobileLabelRequired => _bn ? 'মোবাইল নম্বর' : 'Mobile number';
  static String get mobileRequired => _bn ? 'মোবাইল নম্বর দিন' : 'Enter a mobile number';
  static String get invalidMobile => _bn ? 'সঠিক মোবাইল নম্বর দিন (১১ সংখ্যা, 01…)' : 'Enter a valid mobile number (11 digits, 01…)';
  static String get duplicateCustomerPhone => _bn ? 'এই মোবাইল নম্বরে একজন কাস্টমার আগে থেকেই আছে' : 'A customer with this mobile number already exists';
  static String get addressLabelOptional => _bn ? 'ঠিকানা (ঐচ্ছিক)' : 'Address (optional)';
  static String get amountLabel => _bn ? 'পরিমাণ' : 'Amount';
  static String get amountRequired => _bn ? 'সঠিক পরিমাণ লিখুন' : 'Enter a valid amount';
  static String get noteLabel => _bn ? 'নোট (ঐচ্ছিক)' : 'Note (optional)';
  static String get save => _bn ? 'সেভ করুন' : 'Save';
  static String get add => _bn ? 'যোগ করুন' : 'Add';
  static String get cancel => _bn ? 'বাতিল' : 'Cancel';
  static String get delete => _bn ? 'মুছুন' : 'Delete';

  // Edit / delete customer
  static String get editCustomer => _bn ? 'কাস্টমার এডিট করুন' : 'Edit customer';
  static String get deleteCustomer => _bn ? 'কাস্টমার মুছুন' : 'Delete customer';

  // Transaction history export
  static String get exportHistory => _bn ? 'লেনদেন এক্সপোর্ট করুন' : 'Export transactions';
  static String get historyExportTitle => _bn ? 'লেনদেনের হিসাব' : 'Transaction statement';

  // App update
  static String get updateApp => _bn ? 'অ্যাপ আপডেট' : 'Update app';
  static String get updateAppSubtitle => _bn ? 'নতুন সংস্করণ আছে কিনা দেখুন' : 'Check for a new version';
  static String get updateAvailableTitle => _bn ? 'নতুন আপডেট পাওয়া গেছে' : 'Update available';
  static String updateAvailableBody(String version) => _bn
      ? 'নতুন সংস্করণ (v$version) পাওয়া গেছে। আপডেট করলে আপনার সব তথ্য অপরিবর্তিত থাকবে।'
      : 'A new version (v$version) is available. Your data stays intact after updating.';
  static String get updateNow => _bn ? 'আপডেট করুন' : 'Update';
  static String get updateLater => _bn ? 'পরে' : 'Later';
  static String get updateChecking => _bn ? 'চেক করা হচ্ছে…' : 'Checking…';
  static String updateUpToDate(String version) => _bn ? 'সর্বশেষ সংস্করণ চলছে (v$version)' : 'You are on the latest version (v$version)';

  // Customer-report download (.xlsx)
  static String get downloadReport => _bn ? 'রিপোর্ট ডাউনলোড' : 'Download report';
  static String get downloadTooltip => _bn ? 'সব কাস্টমারের রিপোর্ট (Excel) ডাউনলোড করুন' : 'Download all-customers report (Excel)';
  static String get customerReportTitle => _bn ? 'কাস্টমার রিপোর্ট' : 'Customer report';
  static String get downloadNoCustomers => _bn ? 'ডাউনলোড করার মতো কাস্টমার নেই' : 'No customers to download';
  static String get downloadedToDownloads => _bn ? 'Downloads ফোল্ডারে ডাউনলোড হয়েছে' : 'Downloaded to your Downloads folder';
  static String get downloadSaved => _bn ? 'সেভ হয়েছে' : 'Saved';
  static String get downloadChooseLocation => _bn ? 'জায়গা বেছে নিন' : 'Save to…';
  static String get downloadFailed => _bn ? 'ডাউনলোড ব্যর্থ হয়েছে' : 'Download failed';
  static String get shopLabel => _bn ? 'দোকান' : 'Shop';
  static String get customerLabel => _bn ? 'কাস্টমার' : 'Customer';
  static String get runningDue => _bn ? 'চলতি বাকি' : 'Running due';
  static String get totalTransactions => _bn ? 'মোট লেনদেন' : 'Total transactions';
  static String get currentBalanceLabel => _bn ? 'বর্তমান হিসাব' : 'Current balance';
  static String get madeWithApp => _bn ? 'বাকিবন্ধু অ্যাপ দিয়ে তৈরি' : 'Made with the BakiBondhu app';
  static String get adjustmentUp => _bn ? 'সমন্বয় (বৃদ্ধি)' : 'Adjustment (increase)';
  static String get adjustmentDown => _bn ? 'সমন্বয় (হ্রাস)' : 'Adjustment (decrease)';
  static String get copyText => _bn ? 'কপি করুন' : 'Copy';
  static String get shareText => _bn ? 'শেয়ার করুন' : 'Share';
  static String get copied => _bn ? 'কপি হয়েছে' : 'Copied';
  static String get nothingToExport => _bn ? 'এক্সপোর্ট করার মতো লেনদেন নেই' : 'No transactions to export';
  static String get customerUpdated => _bn ? 'কাস্টমারের তথ্য আপডেট হয়েছে' : 'Customer updated';
  static String get cannotDeleteHasDue => _bn
      ? 'এই কাস্টমারের বাকি আছে — আগে বাকি পরিশোধ করুন, তারপর মুছুন।'
      : 'This customer has an outstanding due — settle it first, then delete.';
  static String deleteCustomerConfirm(String name) => _bn
      ? '“$name”-কে ও তার সব লেনদেনের হিসাব মুছে ফেলবেন? এটি আর ফেরানো যাবে না।'
      : 'Delete “$name” and all their transaction history? This cannot be undone.';

  // Add transaction (Screen 3)
  static String get dateLabel => _bn ? 'তারিখ' : 'Date';
  static String get today => _bn ? 'আজ' : 'Today';
  static String get dueDateLabel => _bn ? 'শেষ তারিখ' : 'Due date';

  // Reminder (Screen 5)
  static String get reminderTitle => _bn ? 'মনে করিয়ে দিন' : 'Send a reminder';
  static String get sendSms => _bn ? 'SMS পাঠান' : 'Send SMS';
  static String get whatsapp => 'WhatsApp';
  static String get editBeforeSend => _bn ? 'পাঠানোর আগে বদলাতে পারেন' : 'You can edit before sending';
  static String get needPhone => _bn ? 'রিমাইন্ডার পাঠাতে মোবাইল নম্বর দরকার' : 'A mobile number is needed to send a reminder';
  static String get nothingDue => _bn ? 'এই কাস্টমারের কোনো বাকি নেই' : 'This customer has no due';
  static String get shopNamePlaceholder => _bn ? 'আপনার দোকান' : 'Your shop';
  static String get couldNotOpen => _bn ? 'অ্যাপটি খোলা গেল না' : 'Could not open the app';

  // Sync Center (Screen §5.14)
  static String get syncCenter => _bn ? 'সিঙ্ক' : 'Sync';
  static String get syncNow => _bn ? 'এখন সিঙ্ক করুন' : 'Sync now';
  static String get synced => _bn ? 'সিঙ্ক হয়েছে' : 'Synced';
  static String get toUpload => _bn ? 'আপলোডের অপেক্ষায়' : 'Waiting to upload';
  static String get failedLabel => _bn ? 'ব্যর্থ' : 'Failed';
  static String get conflictsLabel => _bn ? 'দ্বন্দ্ব' : 'Conflicts';
  static String get allSynced => _bn ? 'সব সিঙ্ক হয়েছে' : 'All synced';
  static String get notConnected => _bn ? 'সার্ভার এখনো যুক্ত হয়নি — সব ডেটা এই ফোনে সংরক্ষিত।' : 'Not connected to the server yet — all data is saved on this phone.';
  static String get conflictsNeedReview => _bn ? 'কিছু লেনদেন পর্যালোচনা দরকার' : 'Some transactions need review';
  static String get conflictReviewSoon => _bn ? 'সার্ভার যুক্ত হলে দ্বন্দ্ব পর্যালোচনা করা যাবে' : 'Conflicts can be reviewed once the server is connected';
  static String syncResult(int pushed, int pulled) => _bn ? 'আপলোড $pushed · ডাউনলোড $pulled' : 'Uploaded $pushed · Downloaded $pulled';

  // Collections (§8.8/§8.9)
  static String get collections => _bn ? 'কালেকশন' : 'Collections';
  static String get recordCollection => _bn ? 'কালেকশন যোগ করুন' : 'Add collection';
  static String get recordPromise => _bn ? 'প্রতিশ্রুতি যোগ করুন' : 'Add promise';
  static String get promises => _bn ? 'প্রতিশ্রুতি' : 'Promises';
  static String get activityHistory => _bn ? 'কালেকশন ইতিহাস' : 'Collection history';
  static String get noActivity => _bn ? 'এখনো কোনো কালেকশন নেই' : 'No collections yet';
  static String get noPromises => _bn ? 'এখনো কোনো প্রতিশ্রুতি নেই' : 'No promises yet';
  static String get methodLabel => _bn ? 'যোগাযোগ' : 'Contact';
  static String get statusLabel => _bn ? 'অবস্থা' : 'Status';
  static String get nextFollowUpLabel => _bn ? 'পরবর্তী ফলো-আপ' : 'Next follow-up';
  static String get promiseAmountLabel => _bn ? 'প্রতিশ্রুত পরিমাণ' : 'Promised amount';
  static String get promiseDateLabel => _bn ? 'প্রতিশ্রুতির তারিখ' : 'Promise date';

  // Settings
  static String get settings => _bn ? 'সেটিংস' : 'Settings';
  static String get shopNameSetting => _bn ? 'দোকানের নাম' : 'Shop name';
  static String get accountSection => _bn ? 'সিঙ্ক ও অ্যাকাউন্ট' : 'Sync & account';
  static String get aboutSection => _bn ? 'সম্পর্কে' : 'About';
  static String get savedMsg => _bn ? 'সংরক্ষিত হয়েছে' : 'Saved';
  static String get notLoggedIn => _bn ? 'লগ ইন করা নেই' : 'Not logged in';

  // Auth (login to sync)
  static String get logIn => _bn ? 'লগ ইন' : 'Log in';
  static String get registerAction => _bn ? 'নিবন্ধন' : 'Register';
  static String get signInToSync => _bn ? 'সিঙ্ক করতে লগ ইন করুন' : 'Log in to sync';
  static String get logOut => _bn ? 'লগ আউট' : 'Log out';
  static String get passwordLabel => _bn ? 'পাসওয়ার্ড' : 'Password';
  static String get businessNameLabel => _bn ? 'দোকান/ব্যবসার নাম' : 'Shop / business name';
  static String get businessRequired => _bn ? 'দোকান/ব্যবসার নাম দিন' : 'Enter the shop / business name';
  static String get yourNameLabel => _bn ? 'আপনার নাম' : 'Your name';
  static String get identifierLabel => _bn ? 'মোবাইল নম্বর' : 'Mobile number';
  static String get bivagLabel => _bn ? 'বিভাগ (ঐচ্ছিক)' : 'Division (optional)';
  static String get thanaLabel => _bn ? 'থানা/উপজেলা (ঐচ্ছিক)' : 'Thana/Upazila (optional)';
  static String get zilaLabel => _bn ? 'জেলা (ঐচ্ছিক)' : 'District (optional)';
  static String get selectBivagHint => _bn ? 'বিভাগ নির্বাচন করুন' : 'Select division';
  static String get selectZilaHint => _bn ? 'জেলা নির্বাচন করুন' : 'Select district';
  static String get selectThanaHint => _bn ? 'থানা/উপজেলা নির্বাচন করুন' : 'Select thana/upazila';
  static String get selectBivagFirst => _bn ? 'আগে বিভাগ নির্বাচন করুন' : 'Select a division first';
  static String get selectZilaFirst => _bn ? 'আগে জেলা নির্বাচন করুন' : 'Select a district first';
  static String get passwordShort => _bn ? 'কমপক্ষে ৬ অক্ষরের পাসওয়ার্ড দিন' : 'Use a password of at least 6 characters';
  static String get toggleToLogin => _bn ? 'অ্যাকাউন্ট আছে? লগ ইন করুন' : 'Have an account? Log in';
  static String get toggleToRegister => _bn ? 'নতুন? নিবন্ধন করুন' : 'New? Register';
  static String get authFailed => _bn ? 'ব্যর্থ হয়েছে' : 'Failed';
  static String loggedInAs(String role) => _bn ? 'লগ ইন করা আছে ($role)' : 'Logged in ($role)';

  // Landing (opening screen) — registered shop owners only; no offline/guest path.
  static String get landingTagline => _bn ? 'বাকির হিসাব সহজে রাখুন।' : 'Keep your credit ledger with ease.';
  static String get landingLogin => _bn ? 'লগ ইন করুন' : 'Log in';
  static String get landingRegister => _bn ? 'নতুন অ্যাকাউন্ট খুলুন' : 'Create a new account';
}
