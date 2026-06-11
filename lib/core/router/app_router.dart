import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_nickname_screen.dart';
import '../../features/auth/screens/signup_profile_screen.dart';
import '../../features/auth/screens/signup_interests_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/review_detail_screen.dart';
import '../../features/review/screens/review_feed_screen.dart';
import '../../features/archive/screens/archive_screen.dart';
import '../../features/archive/screens/archive_detail_screen.dart';
import '../../features/mypage/screens/mypage_screen.dart';
import '../../features/mypage/screens/profile_edit_screen.dart';
import '../../features/mypage/screens/settings_screen.dart';
import '../../features/mypage/screens/blocked_users_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/chat/screens/chat_room_screen.dart';
import '../../features/review/screens/review_write_screen.dart';
import '../../features/community/screens/community_screen.dart';
import '../../features/community/screens/post_detail_screen.dart';
import '../../features/community/screens/post_write_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/mypage/screens/follow_list_screen.dart';
import '../../features/mypage/screens/inquiry_screen.dart';
import '../../features/mypage/screens/ink_book_list_screen.dart';
import '../../features/archive/screens/archive_search_screen.dart';
import '../../features/mypage/screens/ink_book_detail_screen.dart';
import '../../features/mypage/screens/ink_chart_add_screen.dart';
import '../../features/mypage/screens/user_profile_screen.dart';
import '../../features/mypage/screens/terms_screen.dart';
import '../../features/mypage/screens/privacy_screen.dart';
import '../../features/home/screens/notification_screen.dart';
import '../../shared/providers/providers.dart';
import '../shell/main_shell.dart';

// ── RouterNotifier: auth 상태 변화 시 GoRouter 갱신 ──────────────────
final routerNotifierProvider =
    NotifierProvider<RouterNotifier, void>(RouterNotifier.new);

class RouterNotifier extends Notifier<void> with ChangeNotifier {
  @override
  void build() {
    ref.listen(authUserProvider, (_, __) => notifyListeners());
    ref.listen(currentUserProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authValue = ref.read(authUserProvider);
    final userValue = ref.read(currentUserProvider);

    // auth 스트림 로딩 중 — 리다이렉트 보류
    if (authValue.isLoading) return null;

    final isLoggedIn = authValue.value != null;
    final loc = state.matchedLocation;
    final isAuthRoute = loc == '/login' || loc.startsWith('/signup');

    if (!isLoggedIn) {
      return isAuthRoute ? null : '/login';
    }

    // 로그인됨 — 프로필 확인 (유저 문서 로딩 중이면 대기)
    if (userValue.isLoading) return null;

    final hasProfile = userValue.value?.nickname.isNotEmpty == true;

    if (!hasProfile) {
      // 회원가입 플로우는 통과
      if (isAuthRoute) return null;
      return '/signup/nickname';
    }

    // 프로필 완성 — 인증 화면 접근 차단
    if (isAuthRoute) return '/';
    return null;
  }
}

// ── GoRouter ─────────────────────────────────────────────────────────
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider.notifier);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // 인증 화면
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup/nickname', builder: (_, __) => const SignupNicknameScreen()),
      GoRoute(path: '/signup/profile', builder: (_, __) => const SignupProfileScreen()),
      GoRoute(path: '/signup/interests', builder: (_, __) => const SignupInterestsScreen()),

      // 메인 탭 Shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          // 0. 홈 (디스커버리)
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          ]),
          // 1. 리뷰 피드
          StatefulShellBranch(routes: [
            GoRoute(path: '/review', builder: (_, __) => const ReviewFeedScreen()),
          ]),
          // 2. 커뮤니티
          StatefulShellBranch(routes: [
            GoRoute(path: '/community', builder: (_, __) => const CommunityScreen()),
          ]),
          // 3. 아카이브
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/archive',
              builder: (_, __) => const ArchiveScreen(),
            ),
          ]),
          // 4. 마이페이지
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/mypage',
              builder: (_, __) => const MypageScreen(),
              routes: [
                GoRoute(path: 'edit', builder: (_, __) => const ProfileEditScreen()),
                GoRoute(
                  path: 'settings',
                  builder: (_, __) => const SettingsScreen(),
                  routes: [
                    GoRoute(path: 'blocked', builder: (_, __) => const BlockedUsersScreen()),
                    GoRoute(
                      path: 'inquiries',
                      builder: (_, __) => const InquiryListScreen(),
                      routes: [
                        GoRoute(path: 'write', builder: (_, __) => const InquiryWriteScreen()),
                        GoRoute(
                          path: ':inquiryId',
                          builder: (_, state) => InquiryDetailScreen(
                            inquiryId: state.pathParameters['inquiryId']!,
                          ),
                        ),
                      ],
                    ),
                    GoRoute(path: 'terms', builder: (_, __) => const TermsScreen()),
                    GoRoute(path: 'privacy', builder: (_, __) => const PrivacyScreen()),
                  ],
                ),
              ],
            ),
          ]),
        ],
      ),

      // 아카이브 글로벌 라우트
      GoRoute(path: '/archive/search', builder: (_, __) => const ArchiveSearchScreen()),
      GoRoute(
        path: '/archive/:type/:productId',
        builder: (_, state) => ArchiveDetailScreen(
          type: state.pathParameters['type']!,
          productId: state.pathParameters['productId']!,
        ),
      ),

      // 커뮤니티 글로벌 라우트
      GoRoute(path: '/community/write', builder: (_, __) => const PostWriteScreen()),
      GoRoute(
        path: '/community/:postId',
        builder: (_, state) => PostDetailScreen(postId: state.pathParameters['postId']!),
      ),

      // 글로벌 라우트 (탭 외부)
      GoRoute(
        path: '/chat',
        builder: (_, __) => const ChatListScreen(),
        routes: [
          GoRoute(
            path: ':chatId',
            builder: (_, state) => ChatRoomScreen(chatId: state.pathParameters['chatId']!),
          ),
        ],
      ),
      GoRoute(
        path: '/write/review',
        builder: (_, state) => ReviewWriteScreen(
          initialType: state.uri.queryParameters['type'],
          initialProductId: state.uri.queryParameters['productId'],
        ),
      ),
      GoRoute(
        path: '/review/:reviewId',
        builder: (_, state) => ReviewDetailScreen(reviewId: state.pathParameters['reviewId']!),
      ),
      GoRoute(
        path: '/search',
        builder: (_, state) => SearchScreen(
          type: state.uri.queryParameters['type'] ?? 'all',
        ),
      ),
      GoRoute(
        path: '/ink-chart',
        builder: (_, __) => const InkBookListScreen(),
        routes: [
          GoRoute(
            path: ':bookId',
            builder: (_, state) => InkBookDetailScreen(
              bookId: state.pathParameters['bookId']!,
            ),
            routes: [
              GoRoute(
                path: 'add',
                builder: (_, state) => InkChartAddScreen(
                  bookId: state.pathParameters['bookId']!,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/profile/:uid',
        builder: (_, state) =>
            UserProfileScreen(uid: state.pathParameters['uid']!),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationScreen(),
      ),
      GoRoute(
        path: '/profile/:uid/followers',
        builder: (_, state) => FollowListScreen(
          uid: state.pathParameters['uid']!,
          initialTab:
              int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0,
        ),
      ),
    ],
  );
});
