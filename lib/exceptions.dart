class ApiErrorException implements Exception {
  String error;
  String errorDescription;
  ApiErrorException(this.error, this.errorDescription);
}
