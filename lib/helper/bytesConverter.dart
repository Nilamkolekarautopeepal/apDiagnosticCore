class BytesConverter {
  static String hexToASCII(String hex) {
    // Remove any spaces or dashes that might be in the hex string
    String cleanHex = hex.replaceAll(RegExp(r'[\s-]'), '');

    // Ensure the hex string has an even length
    if (cleanHex.length % 2 != 0) {
      cleanHex = '0$cleanHex';
    }

    String ascii = "";

    for (int i = 0; i < cleanHex.length; i += 2) {
      // Extract two characters from hex string
      String part = cleanHex.substring(i, i + 2);

      // Parse it as base 16 and convert to a character
      int charCode = int.parse(part, radix: 16);

      // Add this char to final ASCII string
      ascii += String.fromCharCode(charCode);
    }

    return ascii;
  }
}
