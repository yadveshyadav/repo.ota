class VendorUtils {
  static bool isVendorMatch(String? v1, String? v2) {
    if (v1 == null || v2 == null) return false;
    final s1 = v1.trim().toLowerCase();
    final s2 = v2.trim().toLowerCase();
    if (s1.isEmpty || s2.isEmpty) return false;
    return s1 == s2 || s1.contains(s2) || s2.contains(s1);
  }

  static bool matchesUserVendors(String? machineVendor, Set<String> userVendors) {
    if (machineVendor == null || machineVendor.trim().isEmpty) return false;
    final m = machineVendor.trim().toLowerCase();
    for (final v in userVendors) {
      final s = v.trim().toLowerCase();
      if (s.isNotEmpty && (s == m || m.contains(s) || s.contains(m))) {
        return true;
      }
    }
    return false;
  }
}
