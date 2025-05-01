import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_lighting/screens/login/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const Login()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Expanded(
              flex: 3,
              child: PageView.builder(
                itemCount: onboardingList.length,
                controller: _pageController,
                onPageChanged: (value) {
                  setState(() {
                    _currentIndex = value;
                  });
                },
                itemBuilder: (context, index) {
                  return OnboardingCard(
                    onboarding: onboardingList[index],
                  );
                },
              ),
            ),
            CustomIndicator(position: _currentIndex),
            const SizedBox(height: 60),
            CustomButton(
              width: 200,
              onTap: () {
                if (_currentIndex == onboardingList.length - 1) {
                  _completeOnboarding();
                } else {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.ease,
                  );
                }
              },
              text: _currentIndex == onboardingList.length - 1
                  ? 'Get Started'
                  : 'Next',
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class CustomButton extends StatefulWidget {
  final VoidCallback onTap;
  final String text;
  final double? width;
  final double? height;

  const CustomButton({
    required this.onTap,
    required this.text,
    this.width,
    this.height,
    super.key,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Duration _animationDuration = const Duration(milliseconds: 300);
  final Tween<double> _tween = Tween<double>(begin: 1.0, end: 0.95);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
    )..addListener(() {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _controller.forward().then((_) {
          _controller.reverse();
        });
        widget.onTap();
      },
      child: ScaleTransition(
        scale: _tween.animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
          ),
        ),
        child: Container(
          height: widget.height ?? 60,
          width: widget.width ?? double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xff0D6EFD),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.text,
            style: GoogleFonts.raleway(
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Onboarding {
  final String title;
  final String description;
  final String image;

  Onboarding({
    required this.title,
    required this.description,
    required this.image,
  });
}

List<Onboarding> onboardingList = [
  Onboarding(
    title: 'Smart Lobby Lighting',
    description:
        'Control your lobby lights remotely with ease and elegance, anytime.',
    image: 'assets/onboarding/lights_on.png',
  ),
  Onboarding(
    title: 'Control Your Lights',
    description:
        'Easily manage your lobby lighting with a single tap from anywhere.',
    image: 'assets/onboarding/hand.png',
  ),
  Onboarding(
    title: 'Smart Automation',
    description: 'Automate your lights for convenience and energy savings.',
    image: 'assets/onboarding/girl.png',
  ),
];

class CustomIndicator extends StatelessWidget {
  final int position;

  const CustomIndicator({required this.position, super.key});

  @override
  Widget build(BuildContext context) {
    return DotsIndicator(
      dotsCount: onboardingList.length,
      position: position.toDouble(),
      decorator: DotsDecorator(
        color: Colors.grey.withOpacity(0.5),
        size: const Size.square(8.0),
        activeSize: const Size(20.0, 8.0),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
        activeColor: const Color(0xff0D6EFD),
      ),
    );
  }
}

class OnboardingCard extends StatelessWidget {
  final Onboarding onboarding;

  const OnboardingCard({
    required this.onboarding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            onboarding.image,
            height: 300,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 40),
          Text(
            onboarding.title,
            style: GoogleFonts.raleway(
              textStyle: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xff1A1D1E),
              ),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            onboarding.description,
            style: GoogleFonts.raleway(
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
                color: Color(0xff6A6A6A),
              ),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
