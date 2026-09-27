import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/presentation/widgets/hero_logo.dart';
import '../../features/auth/services/auth_storage_service.dart';
import '../../repositories/auth_repository.dart';
import '../../screens/notifications/notification_screen.dart';
import '../../services/notification_service.dart';

/// Refined Top Application Bar for HERO APP displaying logged-in user details & notifications
class DashboardHeader extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onMenuPressed;
  final VoidCallback? onSidebarToggle;
  final bool isSidebarCollapsed;
  final bool isMobile;
  final bool isRefreshing;
  final String userName;
  final String userRole;
  final String userInitials;

  const DashboardHeader({
    super.key,
    this.onMenuPressed,
    this.onSidebarToggle,
    this.isSidebarCollapsed = false,
    this.isMobile = false,
    this.isRefreshing = false,
    this.userName = 'ADMIN',
    this.userRole = 'ADMIN',
    this.userInitials = 'A',
  });

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  void _showMobileSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Search Fleet & Operations'),
        content: const TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Type machine chassis, site, user name...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.headerGreen,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: isMobile
          ? IconButton(
              icon: const Icon(Icons.menu, color: AppColors.white, size: 22),
              onPressed: onMenuPressed,
              tooltip: 'Open Menu',
            )
          : IconButton(
              icon: Icon(
                isSidebarCollapsed ? Icons.menu_open : Icons.menu,
                color: AppColors.white,
                size: 22,
              ),
              onPressed: onSidebarToggle,
              tooltip: isSidebarCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
            ),
      title: Row(
        children: [
          // User Name & Role - Tapping redirects to Home
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.dashboard,
                  (route) => false,
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            userName,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isRefreshing) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      userRole.toUpperCase(),
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Brand Logo fallback on desktop
        if (!isMobile) ...[
          SizedBox(
            width: 110,
            child: HeroLogo(width: 100),
          ),
          const SizedBox(width: 12),
        ],

        // Search Icon
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: const Icon(
            Icons.search_rounded,
            color: AppColors.white,
            size: 20,
          ),
          onPressed: () => _showMobileSearchDialog(context),
          tooltip: 'Search',
        ),

        const SizedBox(width: 4),

        // Notification Bell Icon with Badge
        ListenableBuilder(
          listenable: NotificationService(),
          builder: (context, child) {
            final user = AuthStorageService().currentUser;
            final unreadCount = NotificationService().getUnreadCountForUser(user?.id ?? '1');

            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.white,
                    size: 22,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationScreen(),
                      ),
                    );
                  },
                  tooltip: 'Notifications',
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.criticalRed,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '$unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        const SizedBox(width: 6),

        // User Profile Menu
        PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          offset: const Offset(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) async {
            if (value == 'logout') {
              await ApiAuthRepository().logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed(AppRoutes.login);
              }
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'Profile',
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 20),
                  const SizedBox(width: 12),
                  Text('$userName ($userRole)'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'Settings',
              child: Row(
                children: [
                  Icon(Icons.settings_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('Settings'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 20, color: AppColors.criticalRed),
                  SizedBox(width: 12),
                  Text(
                    'Logout',
                    style: TextStyle(color: AppColors.criticalRed),
                  ),
                ],
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.white,
              child: Text(
                userInitials,
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
