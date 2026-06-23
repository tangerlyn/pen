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
import '../../features/community/screens/community_screen.dart';
import '../../features/archive/screens/archive_screen.dart';
import '../../features/archive/screens/archive_detail_screen.dart';
import '../../features/mypage/screens/mypage_screen.dart';
import '../../features/mypage/screens/profile_edit_screen.dart';
import '../../features/mypage/screens/settings_screen.dart';
import '../../features/mypage/screens/blocked_users_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/chat/screens/chat_room_screen.dart';
import '../../features/review/screens/review_write_screen.dart';
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
    ref.listen(authUserProvider, (_, _) => notifyListeners());
    ref.listen(currentUserProvider, (_, _) => notifyListeners());
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
      GoRoute(path: '/login', pageBuilder: (_, state) => _fadePage(state, const LoginScreen())),
      GoRoute(path: '/signup/nickname', pageBuilder: (_, state) => _fadePage(state, const SignupNicknameScreen())),
      GoRoute(path: '/signup/profile', pageBuilder: (_, state) => _fadePage(state, const SignupProfileScreen())),
      GoRoute(path: '/signup/interests', pageBuilder: (_, state) => _fadePage(state, const SignupInterestsScreen())),

      // 메인 탭 Shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          // 0. 홈 (디스커버리)
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          ]),
          // 1. 리뷰 피드
          StatefulShellBranch(routes: [
            GoRoute(path: '/review', builder: (_, _) => const ReviewFeedScreen()),
          ]),
          // 2. 커뮤니티
          StatefulShellBranch(routes: [
            GoRoute(path: '/community', builder: (_, _) => const CommunityScreen()),
          ]),
          // 3. 아카이브
          StatefulShellBranch(routes: [
            GoRoute(path: '/archive', builder: (_, _) => const ArchiveScreen()),
          ]),
          // 4. 마이페이지
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/mypage',
              builder: (_, _) => const MypageScreen(),
              routes: [
                GoRoute(path: 'edit', pageBuilder: (_, state) => _slidePage(state, const ProfileEditScreen())),
                GoRoute(
                  path: 'settings',
                  pageBuilder: (_, state) => _slidePage(state, const SettingsScreen()),
                  routes: [
                    GoRoute(path: 'blocked', pageBuilder: (_, state) => _slidePage(state, const BlockedUsersScreen())),
                    GoRoute(
                      path: 'inquiries',
                      pageBuilder: (_, state) => _slidePage(state, const InquiryListScreen()),
                      routes: [
                        GoRoute(path: 'write', pageBuilder: (_, state) => _slideUpPage(state, const InquiryWriteScreen())),
                        GoRoute(
                          path: ':inquiryId',
                          pageBuilder: (_, state) => _slidePage(state, InquiryDetailScreen(
                            inquiryId: state.pathParameters['inquiryId']!,
                          )),
                        ),
                      ],
                    ),
                    GoRoute(path: 'terms', pageBuilder: (_, state) => _slidePage(state, const TermsScreen())),
                    GoRoute(path: 'privacy', pageBuilder: (_, state) => _slidePage(state, const PrivacyScreen())),
                  ],
                ),
              ],
            ),
          ]),
        ],
      ),

      // 아카이브 글로벌 라우트
      GoRoute(path: '/archive/search', pageBuilder: (_, state) => _slidePage(state, const ArchiveSearchScreen())),
      GoRoute(
        path: '/archive/:type/:productId',
        pageBuilder: (_, state) => _slidePage(state, ArchiveDetailScreen(
          type: state.pathParameters['type']!,
          productId: state.pathParameters['productId']!,
        )),
      ),

      // 커뮤니티 글로벌 라우트
      GoRoute(path: '/community/write', pageBuilder: (_, state) => _slideUpPage(state, const PostWriteScreen())),
      GoRoute(
        path: '/community/:postId',
        pageBuilder: (_, state) => _slidePage(state, PostDetailScreen(postId: state.pathParameters['postId']!)),
      ),

      // 채팅 (글로벌)
      GoRoute(
        path: '/chat',
        pageBuilder: (_, state) => _slidePage(state, const ChatListScreen()),
        routes: [
          GoRoute(
            path: ':chatId',
            pageBuilder: (_, state) => _slidePage(state, ChatRoomScreen(chatId: state.pathParameters['chatId']!)),
          ),
        ],
      ),

      GoRoute(
        path: '/write/review',
        pageBuilder: (_, state) => _slideUpPage(state, ReviewWriteScreen(
          initialType: state.uri.queryParameters['type'],
          initialProductId: state.uri.queryParameters['productId'],
        )),
      ),
      GoRoute(
        path: '/review/:reviewId',
        pageBuilder: (_, state) => _slidePage(state, ReviewDetailScreen(reviewId: state.pathParameters['reviewId']!)),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (_, state) => _slidePage(state, SearchScreen(
          type: state.uri.queryParameters['type'] ?? 'all',
        )),
      ),
      GoRoute(
        path: '/ink-chart',
        pageBuilder: (_, state) => _slidePage(state, const InkBookListScreen()),
        routes: [
          GoRoute(
            path: ':bookId',
            pageBuilder: (_, state) => _slidePage(state, InkBookDetailScreen(
              bookId: state.pathParameters['bookId']!,
            )),
            routes: [
              GoRoute(
                path: 'add',
                pageBuilder: (_, state) => _slidePage(state, InkChartAddScreen(
                  bookId: state.pathParameters['bookId']!,
                )),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/profile/:uid',
        pageBuilder: (_, state) => _slidePage(state, UserProfileScreen(uid: state.pathParameters['uid']!)),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (_, state) => _slidePage(state, const NotificationScreen()),
      ),
      GoRoute(
        path: '/profile/:uid/followers',
        pageBuilder: (_, state) => _slidePage(state, FollowListScreen(
          uid: state.pathParameters['uid']!,
          initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0,
        )),
      ),
    ],
  );
});

// ── 화면 전환 헬퍼 ────────────────────────────────────────────────────

// 오른쪽에서 슬라이드 + 페이드 (일반 내비게이션)
CustomTransitionPage<void> _slidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.06, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
          ),
          child: child,
        ),
      );
    },
  );
}

// 아래에서 슬라이드 + 페이드 (글쓰기/작성 화면)
CustomTransitionPage<void> _slideUpPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.07),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );
    },
  );
}

// 페이드만 (인증 화면)
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}
