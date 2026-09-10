import '../models/customer_file.dart';

/// Same selection boundary as SalesBrain: complete permanent PestPac identity.
CustomerSearchResult? canonicalCustomerSearchResult(Map row) {
  String field(String key) => (row[key]?.toString() ?? '').trim();
  if (field('identityState') != 'permanent' ||
      field('locationId').isEmpty ||
      field('pestpacBillToNumber').isEmpty ||
      field('pestpacLocationNumber').isEmpty) {
    return null;
  }
  final location = CustomerLocation(
    billToNumber: field('pestpacBillToNumber'),
    billToName: field('customerName'),
    locationNumber: field('pestpacLocationNumber'),
    locationName: field('locationName'),
    locationAddress: field('serviceAddress'),
    phone: field('phone'),
    email: field('email'),
    customerLocationId: field('locationId'),
    billToId: field('billToId'),
  );
  return CustomerSearchResult(
    billTo: CustomerBillTo(
        billToNumber: location.billToNumber, billToName: location.billToName),
    location: location,
  );
}
