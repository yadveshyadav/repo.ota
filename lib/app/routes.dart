import 'package:flutter/material.dart';
import 'package:hero_app/features/auth/presentation/screens/login_screen.dart';
import 'package:hero_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:hero_app/features/expenses/screens/expense_dashboard_screen.dart';
import 'package:hero_app/features/hindrance/screens/hindrance_screen.dart';
import 'package:hero_app/features/hindrance/screens/ccn_workflow_screen.dart';
import 'package:hero_app/features/inventory/screens/inventory_overview_screen.dart';
import 'package:hero_app/features/live_status/screens/live_status_screen.dart';
import 'package:hero_app/features/tasks/screens/task_detail_screen.dart';
import 'package:hero_app/features/tasks/screens/tasks_screen.dart';
import 'package:hero_app/features/team/screens/team_screen.dart';
import 'package:hero_app/features/vendors/screens/vendors_screen.dart';
import 'package:hero_app/models/task_model.dart';
import 'package:hero_app/screens/alerts/alerts_screen.dart';
import 'package:hero_app/screens/attendance/attendance_screen.dart';
import 'package:hero_app/screens/breakdown/breakdown_machines_screen.dart';
import 'package:hero_app/screens/common/forbidden_screen.dart';
import 'package:hero_app/screens/dashboard/dashboard_screen.dart';
import 'package:hero_app/screens/machines/machine_detail_screen.dart';
import 'package:hero_app/screens/machines/machine_list_screen.dart';
import 'package:hero_app/screens/machines/refuel_history_screen.dart';
import 'package:hero_app/screens/machine_transfer/machine_transfer_detail_screen.dart';
import 'package:hero_app/screens/machine_transfer/machine_transfer_flow_screen.dart';
import 'package:hero_app/screens/machine_transfer/machine_transfers_list_screen.dart';
import 'package:hero_app/screens/notifications/notification_screen.dart';
import 'package:hero_app/screens/roles/roles_permissions_screen.dart';
import 'package:hero_app/shared/widgets/hero_page_route.dart';
import 'package:hero_app/screens/users/users_screen.dart';
import 'package:hero_app/services/authorization_service.dart';

import '../features/auth/services/auth_storage_service.dart';

/// Centralized route definitions and permission-guarded generator for HERO APP.
abstract class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String machines = '/machines';
  static const String machineDetail = '/machine-detail';
  static const String liveStatus = '/live-status';
  static const String vendors = '/vendors';
  static const String tasks = '/tasks';
  static const String hindrance = '/hindrance';
  static const String otn = '/otn';
  static const String ccn = '/ccn';
  static const String taskDetail = '/task-detail';
  static const String team = '/team';
  static const String users = '/users';
  static const String roles = '/roles';
  static const String attendance = '/attendance';
  static const String inventory = '/inventory';
  static const String expenses = '/expenses';
  static const String notifications = '/notifications';
  static const String machineTransfers = '/machine-transfers';
  static const String machineTransferFlow = '/machine-transfer-flow';
  static const String machineTransferDetail = '/machine-transfer-detail';

  // Navigation placeholders
  static const String map = '/map';
  static const String refuel = '/refuel';
  static const String alerts = '/alerts';
  static const String breakdowns = '/breakdowns';
  static const String operators = '/operators';
  static const String settings = '/settings';

  static Map<String, WidgetBuilder> get routes => {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    dashboard: (context) => _guardRoute(
      permission: 'dashboard.view',
      builder: (ctx) => const DashboardScreen(),
    )(context),
    machines: (context) => _guardRoute(
      permission: 'machines.view',
      builder: (ctx) => const MachineListScreen(),
    )(context),
    liveStatus: (context) => _guardRoute(
      permission: 'tracking.view',
      builder: (ctx) => const LiveStatusScreen(),
    )(context),
    vendors: (context) => _guardRoute(
      permission: 'vendors.view',
      builder: (ctx) => const VendorsScreen(),
    )(context),
    tasks: (context) => _guardRoute(
      permission: 'tasks.view',
      builder: (ctx) => const TasksScreen(),
    )(context),
    hindrance: (context) => _guardRoute(
      permission: 'tasks.view',
      builder: (ctx) => const HindranceScreen(),
    )(context),
    otn: (context) => _guardRoute(
      permission: 'tasks.view',
      builder: (ctx) => const HindranceScreen(workflowType: 'OTN'),
    )(context),
    ccn: (context) => _guardRoute(
      permission: 'tasks.view',
      builder: (ctx) => const CcnWorkflowScreen(),
    )(context),
    team: (context) => _guardRoute(
      permission: 'team.view',
      builder: (ctx) => const TeamScreen(),
    )(context),
    users: (context) => _guardRoute(
      permission: 'users.view',
      builder: (ctx) => const UsersScreen(),
    )(context),
    roles: (context) => _guardRoute(
      permission: 'roles.view',
      builder: (ctx) => const RolesPermissionsScreen(),
    )(context),
    attendance: (context) => _guardRoute(
      permission: 'attendance.view',
      builder: (ctx) => const AttendanceScreen(),
    )(context),
    inventory: (context) => _guardRoute(
      permission: 'inventory.view',
      builder: (ctx) => const StockInventoryOverviewScreen(),
    )(context),
    expenses: (context) => _guardRoute(
      permission: 'expenses.view',
      builder: (ctx) => const ExpenseDashboardScreen(),
    )(context),
    notifications: (context) => const NotificationScreen(),
    alerts: (context) => const AlertsScreen(),
    breakdowns: (context) => _guardRoute(
      permission: 'breakdowns.view',
      builder: (ctx) => const BreakdownMachinesScreen(),
    )(context),
    refuel: (context) => _guardRoute(
      permission: 'refuel.view',
      builder: (ctx) => const RefuelHistoryScreen(),
    )(context),
    machineTransfers: (context) {
      final user = AuthStorageService().currentUser;
      if (user != null && user.isVendorUser) {
        return const ForbiddenScreen(routeName: 'Machine Shifting');
      }
      return _guardRoute(
        permission: 'machines.view',
        builder: (ctx) => const MachineTransfersListScreen(),
      )(context);
    },
    machineTransferFlow: (context) {
      final user = AuthStorageService().currentUser;
      if (user != null && user.isVendorUser) {
        return const ForbiddenScreen(routeName: 'Machine Shifting');
      }
      return _guardRoute(
        permission: 'machines.view',
        builder: (ctx) => const MachineTransferFlowScreen(),
      )(context);
    },
  };

  static WidgetBuilder _guardRoute({
    required String permission,
    required WidgetBuilder builder,
  }) {
    return (BuildContext context) {
      if (AuthorizationService.instance.can(permission)) {
        return builder(context);
      }
      return ForbiddenScreen(routeName: permission);
    };
  }

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      case dashboard:
        return _buildGuardedPageRoute(
          permission: 'dashboard.view',
          builder: (_) => const DashboardScreen(),
          settings: settings,
        );
      case machines:
        return _buildGuardedPageRoute(
          permission: 'machines.view',
          builder: (_) => const MachineListScreen(),
          settings: settings,
        );
      case liveStatus:
        return _buildGuardedPageRoute(
          permission: 'tracking.view',
          builder: (_) => const LiveStatusScreen(),
          settings: settings,
        );
      case vendors:
        return _buildGuardedPageRoute(
          permission: 'vendors.view',
          builder: (_) => const VendorsScreen(),
          settings: settings,
        );
      case tasks:
        return _buildGuardedPageRoute(
          permission: 'tasks.view',
          builder: (_) => const TasksScreen(),
          settings: settings,
        );
      case hindrance:
        return _buildGuardedPageRoute(
          permission: 'tasks.view',
          builder: (_) => const HindranceScreen(),
          settings: settings,
        );
      case ccn:
        return _buildGuardedPageRoute(
          permission: 'tasks.view',
          builder: (_) => const CcnWorkflowScreen(),
          settings: settings,
        );
      case taskDetail:
        final task = settings.arguments as TaskModel?;
        if (task == null) {
          return MaterialPageRoute(builder: (_) => const TasksScreen());
        }
        return _buildGuardedPageRoute(
          permission: 'tasks.view',
          builder: (_) => TaskDetailScreen(task: task),
          settings: settings,
        );
      case team:
        return _buildGuardedPageRoute(
          permission: 'team.view',
          builder: (_) => const TeamScreen(),
          settings: settings,
        );
      case users:
        return _buildGuardedPageRoute(
          permission: 'users.view',
          builder: (_) => const UsersScreen(),
          settings: settings,
        );
      case roles:
        return _buildGuardedPageRoute(
          permission: 'roles.view',
          builder: (_) => const RolesPermissionsScreen(),
          settings: settings,
        );
      case attendance:
        return _buildGuardedPageRoute(
          permission: 'attendance.view',
          builder: (_) => const AttendanceScreen(),
          settings: settings,
        );
      case inventory:
        return _buildGuardedPageRoute(
          permission: 'inventory.view',
          builder: (_) => const StockInventoryOverviewScreen(),
          settings: settings,
        );
      case expenses:
        return _buildGuardedPageRoute(
          permission: 'expenses.view',
          builder: (_) => const ExpenseDashboardScreen(),
          settings: settings,
        );
      case notifications:
        return MaterialPageRoute(
          builder: (_) => const NotificationScreen(),
          settings: settings,
        );
      case alerts:
        return MaterialPageRoute(
          builder: (_) => const AlertsScreen(),
          settings: settings,
        );
      case breakdowns:
        return _buildGuardedPageRoute(
          permission: 'breakdowns.view',
          builder: (_) => const BreakdownMachinesScreen(),
          settings: settings,
        );
      case refuel:
        return _buildGuardedPageRoute(
          permission: 'refuel.view',
          builder: (_) => const RefuelHistoryScreen(),
          settings: settings,
        );
      case machineDetail:
        final chassisNo = settings.arguments as String? ?? '';
        return _buildGuardedPageRoute(
          permission: 'machines.view',
          builder: (_) => MachineDetailScreen(chassisNo: chassisNo),
          settings: settings,
        );
      case machineTransfers:
        return _buildGuardedPageRoute(
          permission: 'machines.view',
          builder: (_) => const MachineTransfersListScreen(),
          settings: settings,
        );
      case machineTransferFlow:
        return _buildGuardedPageRoute(
          permission: 'machines.view',
          builder: (_) => const MachineTransferFlowScreen(),
          settings: settings,
        );
      case machineTransferDetail:
        final transferId = settings.arguments as String? ?? '';
        return _buildGuardedPageRoute(
          permission: 'machines.view',
          builder: (_) => MachineTransferDetailScreen(transferId: transferId),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
    }
  }

  static Route<dynamic> _buildGuardedPageRoute({
    required String permission,
    required WidgetBuilder builder,
    required RouteSettings settings,
  }) {
    if (AuthorizationService.instance.can(permission)) {
      return HeroPageRoute(builder: builder, settings: settings);
    }
    return HeroPageRoute(
      builder: (_) => ForbiddenScreen(routeName: settings.name ?? permission),
      settings: settings,
    );
  }
}
