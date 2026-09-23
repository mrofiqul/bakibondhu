/// Country list for shop-owner registration. Bangladesh is the default and
/// first; picking a different country switches the location fields from the
/// Bangladesh division→district→thana cascade to free-text State + City, and
/// defaults the app language to English.
class Country {
  final String code; // ISO-3166 alpha-2 (used for device-region detection)
  final String name; // English display name
  const Country(this.code, this.name);
}

/// Bangladesh first, then common neighbours and diaspora destinations, then a
/// catch-all. Kept intentionally curated (not the full ISO list) so the dropdown
/// stays usable; "Other" covers anything not listed.
const List<Country> kCountries = [
  Country('BD', 'Bangladesh'),
  Country('IN', 'India'),
  Country('PK', 'Pakistan'),
  Country('NP', 'Nepal'),
  Country('LK', 'Sri Lanka'),
  Country('BT', 'Bhutan'),
  Country('MV', 'Maldives'),
  Country('MM', 'Myanmar'),
  Country('SA', 'Saudi Arabia'),
  Country('AE', 'United Arab Emirates'),
  Country('QA', 'Qatar'),
  Country('KW', 'Kuwait'),
  Country('OM', 'Oman'),
  Country('BH', 'Bahrain'),
  Country('JO', 'Jordan'),
  Country('LB', 'Lebanon'),
  Country('MY', 'Malaysia'),
  Country('SG', 'Singapore'),
  Country('ID', 'Indonesia'),
  Country('BN', 'Brunei'),
  Country('GB', 'United Kingdom'),
  Country('US', 'United States'),
  Country('CA', 'Canada'),
  Country('AU', 'Australia'),
  Country('IT', 'Italy'),
  Country('FR', 'France'),
  Country('DE', 'Germany'),
  Country('ES', 'Spain'),
  Country('PT', 'Portugal'),
  Country('GR', 'Greece'),
  Country('ZA', 'South Africa'),
  Country('JP', 'Japan'),
  Country('KR', 'South Korea'),
  Country('XX', 'Other'),
];

const String kDefaultCountry = 'Bangladesh';

/// The display name for an ISO country code, or null when it isn't in the list.
String? countryNameForCode(String? code) {
  if (code == null || code.isEmpty) return null;
  final up = code.toUpperCase();
  for (final c in kCountries) {
    if (c.code == up) return c.name;
  }
  return null;
}

bool isBangladesh(String? countryName) =>
    countryName == null || countryName == kDefaultCountry;
