import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/auth_controller.dart';
import '../features/auth/domain/user_role.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/role_select_screen.dart';
import '../features/favorites/presentation/favorites_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/properties/presentation/add_property_screen.dart';
import '../features/properties/presentation/property_details_screen.dart';
import '../features/reels/presentation/reels_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/shell/presentation/app_shell.dart';
import '../features/chat/presentation/chat_list_screen.dart';
import '../features/chat/presentation/chat_room_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/requests/presentation/my_property_requests_screen.dart';
import '../features/requests/presentation/property_request_form_screen.dart';
import '../features/marketers/presentation/marketer_profile_screen.dart';
import '../features/marketers/presentation/marketers_list_screen.dart';
import '../features/offices/presentation/offices_list_screen.dart';
import '../features/offices/presentation/office_profile_screen.dart';
import '../features/parcels/presentation/parcel_profile_screen.dart';
import '../features/parcels/presentation/parcels_list_screen.dart';
import '../features/compounds/presentation/compound_profile_screen.dart';
import '../features/compounds/presentation/compounds_list_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/news/presentation/property_news_detail_screen.dart';
import '../features/properties/presentation/properties_map_screen.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // لا نستخدم watch(auth) هنا — أي تغيير بنوع حساب الضيف يعيد بناء GoRouter بالكامل ويسبب وميضاً.
  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: _GoRouterRefresh(ref),
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;

      final isAuth = auth.isAuthenticated;
      final isAuthFlow =
          loc == AppRoutes.login ||
          loc == AppRoutes.register ||
          loc == AppRoutes.role;

      // الضيف يقدر يتصفح (Home/Search/Reels/Details) بدون تسجيل
      final guestAllowed =
          loc == AppRoutes.home ||
          loc == AppRoutes.search ||
          loc == AppRoutes.reels ||
          loc == AppRoutes.marketers ||
          loc == AppRoutes.offices ||
          loc == AppRoutes.parcels ||
          loc == AppRoutes.compounds ||
          loc == AppRoutes.propertiesMap ||
          loc.startsWith('${AppRoutes.parcelProfile}/') ||
          loc.startsWith('${AppRoutes.compoundProfile}/') ||
          loc.startsWith('${AppRoutes.officeProfile}/') ||
          loc.startsWith('${AppRoutes.marketerProfile}/') ||
          loc.startsWith(AppRoutes.propertyDetails) ||
          loc.startsWith('${AppRoutes.newsDetail}/');

      // صفحات تتطلب تسجيل دخول
      final requiresAuth =
          loc == AppRoutes.chats ||
          loc == AppRoutes.profile ||
          loc == AppRoutes.favorites ||
          loc == AppRoutes.addProperty ||
          loc == AppRoutes.notifications ||
          loc == AppRoutes.requestProperty ||
          loc == AppRoutes.myPropertyRequests ||
          loc.startsWith(AppRoutes.chatRoom);

      if (!isAuth && requiresAuth) return AppRoutes.login;
      if (isAuth && isAuthFlow) {
        return auth.role == UserRole.office
            ? AppRoutes.offices
            : AppRoutes.home;
      }
      if (!isAuth && !guestAllowed && !isAuthFlow) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, redirect: (_, _) => AppRoutes.home),
      GoRoute(
        path: AppRoutes.role,
        builder: (_, _) => const RoleSelectScreen(),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.chatRoom}/:chatId',
        builder: (context, state) => ChatRoomScreen(
          chatId: state.pathParameters['chatId']!,
          propertyId: state.uri.queryParameters['property'],
          reelId: state.uri.queryParameters['reel_id'],
          fromReelTitle: state.uri.queryParameters['reel'],
          supportChat: state.uri.queryParameters['support'] == '1',
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: AppRoutes.search,
            builder: (_, _) => const SearchScreen(),
          ),
          GoRoute(
            path: AppRoutes.reels,
            builder: (context, state) => ReelsScreen(
              openComposer: state.uri.queryParameters['compose'] == '1',
              initialReelId: state.uri.queryParameters['reel_id'],
              ownerId: state.uri.queryParameters['owner_id'],
            ),
          ),
          GoRoute(
            path: AppRoutes.chats,
            builder: (_, _) => const ChatListScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, _) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.offices,
            builder: (_, _) => const OfficesListScreen(),
          ),
          GoRoute(
            path: AppRoutes.marketers,
            builder: (_, _) => const MarketersListScreen(),
          ),
          GoRoute(
            path: '${AppRoutes.marketerProfile}/:marketerId',
            builder: (context, state) => MarketerProfileScreen(
              marketerId: state.pathParameters['marketerId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.parcels,
            builder: (_, _) => const ParcelsListScreen(),
          ),
          GoRoute(
            path: AppRoutes.compounds,
            builder: (_, _) => const CompoundsListScreen(),
          ),
          GoRoute(
            path: AppRoutes.propertiesMap,
            builder: (_, _) => const PropertiesMapScreen(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (_, _) => const NotificationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.requestProperty,
            builder: (_, _) => const PropertyRequestFormScreen(),
          ),
          GoRoute(
            path: AppRoutes.myPropertyRequests,
            builder: (_, _) => const MyPropertyRequestsScreen(),
          ),
          GoRoute(
            path: '${AppRoutes.officeProfile}/:officeId',
            builder: (context, state) => OfficeProfileScreen(
              officeId: state.pathParameters['officeId']!,
            ),
          ),
          GoRoute(
            path: '${AppRoutes.parcelProfile}/:parcelId',
            builder: (context, state) {
              final titleRaw = state.uri.queryParameters['title'];
              final title = titleRaw == null || titleRaw.trim().isEmpty
                  ? 'المقاطعة'
                  : titleRaw.trim();
              final postsRaw = state.uri.queryParameters['posts'];
              final posts = int.tryParse(postsRaw ?? '');
              return ParcelProfileScreen(
                parcelId: state.pathParameters['parcelId']!,
                title: title,
                expectedPostsCount: posts != null && posts > 0 ? posts : null,
              );
            },
          ),
          GoRoute(
            path: '${AppRoutes.compoundProfile}/:compoundId',
            builder: (context, state) {
              final titleRaw = state.uri.queryParameters['title'];
              final title = titleRaw == null || titleRaw.trim().isEmpty
                  ? 'مجمع سكني'
                  : titleRaw.trim();
              final postsRaw = state.uri.queryParameters['posts'];
              final posts = int.tryParse(postsRaw ?? '');
              return CompoundProfileScreen(
                compoundId: state.pathParameters['compoundId']!,
                title: title,
                expectedPostsCount: posts != null && posts > 0 ? posts : null,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '${AppRoutes.propertyDetails}/:id',
        builder: (context, state) =>
            PropertyDetailsScreen(propertyId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '${AppRoutes.newsDetail}/:id',
        builder: (context, state) =>
            PropertyNewsDetailScreen(newsId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.addProperty,
        builder: (_, state) => AddPropertyScreen(
          editPropertyId: state.uri.queryParameters['edit_property_id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.favorites,
        builder: (_, _) => const FavoritesScreen(),
      ),
    ],
    errorBuilder: (_, state) => _RouterErrorScreen(error: state.error),
  );
});

class _GoRouterRefresh extends ChangeNotifier {
  _GoRouterRefresh(this.ref) {
    ref.listen(authControllerProvider, (prev, next) {
      // تجاهل تغيّر «نوع الحساب» للضيف فقط — يمنع وميض الرئيسية عند اختيار شخصي/مكتب في التسجيل.
      if (prev?.isAuthenticated != next.isAuthenticated ||
          prev?.apiToken != next.apiToken ||
          prev?.userId != next.userId) {
        notifyListeners();
      }
    });
  }

  final Ref ref;
}

class _RouterErrorScreen extends StatelessWidget {
  const _RouterErrorScreen({required this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          error?.toString() ?? 'حدث خطأ غير متوقع',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
