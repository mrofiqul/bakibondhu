<?php
// Latest published app versions, served at GET /api/v1/app/version.
// Already-installed apps compare their own build to these and prompt the owner
// to update when a newer one is available. BUMP THESE AT EACH RELEASE:
//   - android.version / android.build  -> the new APK's versionName / versionCode
//   - web.build                        -> match WEB_BUILD in app/index.html
// Updating never touches the user's data; it only installs a newer build.
return [
    'android' => [
        'version' => '0.1.25',
        'build'   => 26,
        'url'     => 'https://github.com/mrofiqul/bakibondhu-app/releases/latest/download/BakiBondhu.apk',
        'notes'   => 'নতুন: অনলাইন হলে নিজে থেকে সিঙ্ক (স্বয়ংক্রিয় সিঙ্ক)।',
    ],
    'web' => [
        'build'   => 6,
        'notes'   => 'নতুন সংস্করণ পাওয়া গেছে।',
    ],
];
