import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ثيم التطبيق - ألوان مستوحاة من خشب/تنجيد (بني دافئ + كحلي + عنابي)
class AppColors {
  AppColors._();

  static const Color wood = Color(0xFF8B5E34); // بني خشبي دافئ
  static const Color woodDark = Color(0xFF5C3D21);
  static const Color amber = Color(0xFFD9A441); // أصفر ذهبي/عنبري
  static const Color charcoal = Color(0xFF2B2B2B);
  static const Color navy = Color(0xFF1F3A5F);

  static const Color success = Color(0xFF2E7D32); // مدفوع بالكامل
  static const Color warning = Color(0xFFC9962C); // مديونية جزئية
  static const Color danger = Color(0xFFB3261E); // مديونية / متأخر

  static const Color lightBg = Color(0xFFFAF6F0);
  static const Color darkBg = Color(0xFF1A1A1A);
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.wood,
        secondary: AppColors.amber,
        error: AppColors.danger,
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.cairoTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.wood,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.wood,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.wood,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColors.wood, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.wood, width: 2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: AppColors.wood,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 10,
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.amber,
        secondary: AppColors.wood,
        error: AppColors.danger,
        surface: AppColors.charcoal,
      ),
      textTheme: GoogleFonts.cairoTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.charcoal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF262626),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.amber,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.amber,
          minimumSize: const Size(double.infinity, 52),
          // حد أعرض وأفتح في الوضع الداكن عشان يفرق بوضوح عن الخلفية الغامقة
          // (الحد الافتراضي رمادي باهت وبيبقى بالكاد باين)
          side: const BorderSide(color: AppColors.amber, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: AppColors.amber,
        unselectedItemColor: Colors.grey,
        backgroundColor: AppColors.charcoal,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
