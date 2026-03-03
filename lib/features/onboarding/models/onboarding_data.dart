class OnboardingData {
  final String imagePath;
  final String title;
  final String description;

  const OnboardingData({
    required this.imagePath,
    required this.title,
    required this.description,
  });

  static const List<OnboardingData> pages = [
    OnboardingData(
      imagePath: 'assets/images/onboarding/onboarding_1.png',
      title: 'Welcome to\nEnterprise Ticketing',
      description:
          "Your go-to app for quick and efficient IT support. We're here to make your work life smoother.",
    ),
    OnboardingData(
      imagePath: 'assets/images/onboarding/onboarding_2.png',
      title: 'Report Issues\nInstantly',
      description:
          'Create IT support tickets in seconds. Snap a photo of your hardware issue for faster resolution.',
    ),
    OnboardingData(
      imagePath: 'assets/images/onboarding/onboarding_3.png',
      title: 'Stay Updated\nand Connected',
      description:
          "Track your ticket's status from open to resolved and chat directly with IT agents for real-time updates.",
    ),
    OnboardingData(
      imagePath: 'assets/images/onboarding/onboarding_4.png',
      title: 'Get Back\nto Business',
      description:
          "Ready to experience streamlined IT support? Let's solve your issues and keep your work flowing.",
    ),
  ];
}
