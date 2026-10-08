/// Countries offered at sign-up (India first, 'Other' last). Names stay in
/// English, the international convention for country pickers.
class Country {
  const Country(this.code, this.name, this.flag);
  final String code;
  final String name;
  final String flag;
}

const List<Country> countries = [
  Country('IN', "India", '🇮🇳'),
  Country('US', "United States", '🇺🇸'),
  Country('GB', "United Kingdom", '🇬🇧'),
  Country('CA', "Canada", '🇨🇦'),
  Country('FR', "France", '🇫🇷'),
  Country('AU', "Australia", '🇦🇺'),
  Country('DE', "Germany", '🇩🇪'),
  Country('AE', "United Arab Emirates", '🇦🇪'),
  Country('SA', "Saudi Arabia", '🇸🇦'),
  Country('NP', "Nepal", '🇳🇵'),
  Country('BD', "Bangladesh", '🇧🇩'),
  Country('PK', "Pakistan", '🇵🇰'),
  Country('LK', "Sri Lanka", '🇱🇰'),
  Country('SG', "Singapore", '🇸🇬'),
  Country('MY', "Malaysia", '🇲🇾'),
  Country('ID', "Indonesia", '🇮🇩'),
  Country('PH', "Philippines", '🇵🇭'),
  Country('TH', "Thailand", '🇹🇭'),
  Country('VN', "Vietnam", '🇻🇳'),
  Country('JP', "Japan", '🇯🇵'),
  Country('KR', "South Korea", '🇰🇷'),
  Country('CN', "China", '🇨🇳'),
  Country('NZ', "New Zealand", '🇳🇿'),
  Country('ZA', "South Africa", '🇿🇦'),
  Country('NG', "Nigeria", '🇳🇬'),
  Country('KE', "Kenya", '🇰🇪'),
  Country('EG', "Egypt", '🇪🇬'),
  Country('QA', "Qatar", '🇶🇦'),
  Country('KW', "Kuwait", '🇰🇼'),
  Country('OM', "Oman", '🇴🇲'),
  Country('BH', "Bahrain", '🇧🇭'),
  Country('IT', "Italy", '🇮🇹'),
  Country('ES', "Spain", '🇪🇸'),
  Country('PT', "Portugal", '🇵🇹'),
  Country('NL', "Netherlands", '🇳🇱'),
  Country('BE', "Belgium", '🇧🇪'),
  Country('CH', "Switzerland", '🇨🇭'),
  Country('AT', "Austria", '🇦🇹'),
  Country('SE', "Sweden", '🇸🇪'),
  Country('NO', "Norway", '🇳🇴'),
  Country('DK', "Denmark", '🇩🇰'),
  Country('FI', "Finland", '🇫🇮'),
  Country('IE', "Ireland", '🇮🇪'),
  Country('PL', "Poland", '🇵🇱'),
  Country('RU', "Russia", '🇷🇺'),
  Country('TR', "Turkey", '🇹🇷'),
  Country('BR', "Brazil", '🇧🇷'),
  Country('MX', "Mexico", '🇲🇽'),
  Country('AR', "Argentina", '🇦🇷'),
  Country('CL', "Chile", '🇨🇱'),
  Country('CO', "Colombia", '🇨🇴'),
  Country('MU', "Mauritius", '🇲🇺'),
  Country('FJ', "Fiji", '🇫🇯'),
  Country('TT', "Trinidad and Tobago", '🇹🇹'),
  Country('GY', "Guyana", '🇬🇾'),
  Country('SR', "Suriname", '🇸🇷'),
  Country('ZZ', "Other", '🌍'),
];

Country? countryByCode(String? code) {
  for (final c in countries) {
    if (c.code == code) return c;
  }
  return null;
}
