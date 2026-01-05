const Map<String, String> roleDashboardRoutes = <String, String>{
  'learner': '/dashboard/learner',
  'educator': '/dashboard/educator',
  'parent': '/dashboard/parent',
  'site': '/dashboard/site',
  'partner': '/dashboard/partner',
  'hq': '/dashboard/hq',
};

String dashboardRouteFor(String role) {
  return roleDashboardRoutes[role] ?? roleDashboardRoutes['learner']!;
}

bool rolePermitted(String role, Set<String> entitlements) {
  if (entitlements.isEmpty) return false;
  if (entitlements.contains('superuser')) return true;
  return entitlements.contains(role);
}
