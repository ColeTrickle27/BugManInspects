import '../models/trace_geometry.dart';

class AddressSuggestion {
  const AddressSuggestion({
    required this.id,
    required this.address,
    required this.primaryText,
    this.secondaryText,
  });

  final String id;
  final String address;
  final String primaryText;
  final String? secondaryText;
}

class AddressQuality {
  const AddressQuality({
    required this.geocodeGranularity,
    required this.validationGranularity,
    required this.isPropertyLevel,
    required this.addressComplete,
    required this.requiresReview,
    this.dpvConfirmation,
  });

  final String geocodeGranularity;
  final String validationGranularity;
  final bool isPropertyLevel;
  final bool addressComplete;
  final bool requiresReview;
  final String? dpvConfirmation;
}

class AddressSelection {
  const AddressSelection({
    required this.standardizedAddress,
    required this.quality,
    this.coordinate,
  });

  final String standardizedAddress;
  final GeoPoint? coordinate;
  final AddressQuality quality;
}

abstract class AddressSuggestionService {
  Future<List<AddressSuggestion>> suggest(
    String query, {
    required String sessionToken,
  });

  Future<AddressSelection> select(
    AddressSuggestion suggestion, {
    required String sessionToken,
  });
}
