abstract class AppConstants {
  static const String appName = 'Nibpen';

  // Firestore collections
  static const String usersCol = 'users';
  static const String inksCol = 'inks';
  static const String pensCol = 'pens';
  static const String reviewsCol = 'reviews';
  static const String listingsCol = 'listings';
  static const String chatRoomsCol = 'chatRooms';
  static const String messagesCol = 'messages';
  static const String followsCol = 'follows';
  static const String reportsCol = 'reports';
  static const String notificationsCol = 'notifications';

  // Storage paths
  static const String profileImagesPath = 'profiles';
  static const String reviewImagesPath = 'reviews';
  static const String listingImagesPath = 'listings';
  static const String chatImagesPath = 'chats';

  // 제한
  static const int maxReviewImages = 10;
  static const int maxListingImages = 10;
  static const int maxReviewTags = 5;
  static const int maxNickname = 12;
  static const int maxBio = 100;
  static const int maxReviewBody = 500;
  static const int maxPostTitle = 50;
  static const int maxPostBody = 2000;
  static const int maxComment = 300;
  static const int maxReply = 200;

  // 카카오
  static const String kakaoNativeAppKey = 'YOUR_KAKAO_NATIVE_APP_KEY';

  // 네이버
  static const String naverClientId = 'YOUR_NAVER_CLIENT_ID';
  static const String naverClientSecret = 'YOUR_NAVER_CLIENT_SECRET';
  static const String naverClientName = 'Nibpen';


  // 채팅 위험 패턴 (전화번호·계좌번호)
  static final phonePattern = RegExp(r'0\d{1,2}[-\s]?\d{3,4}[-\s]?\d{4}');
  static final accountPattern = RegExp(r'\d{3,4}[-\s]?\d{4,6}[-\s]?\d{4,6}');
}

abstract class AppStrings {
  static const List<String> interestCategories = ['잉크', '만년필'];
  static const List<String> reviewFilterChips = ['전체', '잉크', '만년필'];
  static const List<String> inkColorFamilies = ['Red', 'Blue', 'Green', 'Black', 'Brown', 'Purple', 'Pink', 'Gray', 'Orange', 'Yellow'];
  static const List<String> inkTypes = ['일반', '펄', '테', '형광'];
  static const List<String> nibSizes = ['EF', 'F', 'FM', 'M', 'B', 'BB', 'Stub', 'FA', 'Music'];
  static const List<String> nibMaterials = ['금닙 14K', '금닙 18K', '금닙 21K', '스틸닙'];
  static const List<String> fillTypes = ['카트리지·컨버터', '피스톤', '아이드로퍼', '진공'];
  static const List<String> rulingTypes = ['무지', '줄지', '모눈', '도트'];
  static const List<String> conditions = ['미개봉', 'S급', 'A급', 'B급', 'C급'];
  static const List<String> tradeTypes = ['택배', '직거래', '둘다'];
  static const List<String> marketCategories = ['전체', '잉크', '만년필', '종이', '펜', '샤프', '기타'];
  static const List<String> sortOptions = ['최신순', '낮은가격순', '높은가격순'];
}
