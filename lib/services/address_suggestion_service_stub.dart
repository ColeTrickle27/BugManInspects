import 'address_suggestion_service.dart';

AddressSuggestionService createAddressSuggestionService() =>
    UnsupportedAddressSuggestionService();

class UnsupportedAddressSuggestionService implements AddressSuggestionService {
  @override
  Future<AddressSelection> select(
    AddressSuggestion suggestion, {
    required String sessionToken,
  }) async =>
      throw const AddressSuggestionServiceException(
        'Address suggestions are currently available in the web app.',
      );

  @override
  Future<List<AddressSuggestion>> suggest(
    String query, {
    required String sessionToken,
  }) async =>
      throw const AddressSuggestionServiceException(
        'Address suggestions are currently available in the web app.',
      );
}

class AddressSuggestionServiceException implements Exception {
  const AddressSuggestionServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
