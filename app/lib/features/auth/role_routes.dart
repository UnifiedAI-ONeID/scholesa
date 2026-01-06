String normalizeRole(String role) {
  final normalized = role.trim().toLowerCase();
  switch (normalized) {
    case 'hq_admin':
    case 'hqadmin':
    case 'admin':
      return 'hq';
    case 'site_lead':
    case 'sitelead':
    case 'site-lead':
    case 'site_admin':
    case 'siteadmin':
      return 'site';
    case 'guardian':
    case 'parent_guardian':
      return 'parent';
    case 'teacher':
      return 'educator';
    case 'student':
      return 'learner';
    default:
      return normalized;
  }
}

const Map<String, String> roleDashboardRoutes = <String, String>{
  'learner': '/dashboard/learner',
  'educator': '/dashboard/educator',
  'parent': '/dashboard/parent',
  'site': '/dashboard/site',
  'partner': '/dashboard/partner',
  'hq': '/dashboard/hq',
};

String dashboardRouteFor(String role) {
  final normalized = normalizeRole(role);
  if (normalized == 'superuser') return roleDashboardRoutes['hq']!;
  return roleDashboardRoutes[normalized] ?? roleDashboardRoutes['learner']!;
}

bool rolePermitted(String role, Set<String> entitlements) {
  if (entitlements.isEmpty) return false;
  final normalizedEntitlements = entitlements.map(normalizeRole).toSet();
  if (normalizedEntitlements.contains('superuser')) return true;
  return normalizedEntitlements.contains(normalizeRole(role));
}
