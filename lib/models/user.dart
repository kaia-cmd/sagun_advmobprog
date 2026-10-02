// Enhancement 3: User model shared by both auth back ends. DummyJSON fills id,
// gender and image from /auth/login; Firebase fills uid, age and phone from
// the FirebaseAuth user plus the profile captured on the signup screen.
// UserService persists and rehydrates it via SharedPreferences.
class User {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String gender;
  final String image;
  final String accessToken;
  final String refreshToken;
  final String loginType; // 'dummyjson' or 'firebase' (see LoginType)
  final String uid; // Firebase uid, empty for DummyJSON users
  final int age;
  final String phone;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.image,
    required this.accessToken,
    required this.refreshToken,
    this.loginType = 'dummyjson',
    this.uid = '',
    this.age = 0,
    this.phone = '',
  });

  String get fullName => '$firstName $lastName'.trim();

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      gender: json['gender'] ?? '',
      image: json['image'] ?? '',
      accessToken: json['accessToken'] ?? json['token'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      loginType: json['loginType'] ?? 'dummyjson',
      uid: json['uid'] ?? '',
      age: json['age'] ?? 0,
      phone: json['phone'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender,
      'image': image,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'loginType': loginType,
      'uid': uid,
      'age': age,
      'phone': phone,
    };
  }
}
