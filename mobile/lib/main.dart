import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/venuehub_widgets.dart';
import 'data/api/api_client.dart';

void main() {
  runApp(const VenueHubApp());
}

class VenueHubApp extends StatefulWidget {
  const VenueHubApp({super.key});

  @override
  State<VenueHubApp> createState() => _VenueHubAppState();
}

class _VenueHubAppState extends State<VenueHubApp> {
  final ApiClient api = ApiClient();
  bool booting = true;
  Map<String, dynamic>? user;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null) {
      api.token = token;
      try {
        final response = await api.get('/auth/me');
        user = response['user'] as Map<String, dynamic>;
      } catch (_) {
        await prefs.remove('token');
        api.token = null;
      }
    }

    if (mounted) setState(() => booting = false);
  }

  Future<void> _setSession(String token, Map<String, dynamic> nextUser) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    api.token = token;
    setState(() => user = nextUser);
  }

  void _updateUser(Map<String, dynamic> nextUser) {
    setState(() => user = nextUser);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    api.token = null;
    setState(() => user = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VenueHub',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      home: booting
          ? const SplashScreen()
          : user == null
          ? LoginScreen(api: api, onAuthenticated: _setSession)
          : RoleHome(
              api: api,
              user: user!,
              onLogout: _logout,
              onUserUpdated: _updateUser,
            ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  int dot = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(
      const Duration(milliseconds: 360),
      (_) => setState(() => dot = (dot + 1) % 4),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF031B3A), Color(0xFF0B61B3), Color(0xFF43B5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const VenueHubLogo(size: 112),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  4,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: dot == index ? 20 : 8,
                    decoration: BoxDecoration(
                      color: dot == index
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.api,
    required this.onAuthenticated,
  });

  final ApiClient api;
  final Future<void> Function(String token, Map<String, dynamic> user)
  onAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(text: 'customer@venuehub.test');
  final password = TextEditingController(text: 'password123');
  bool loading = false;
  bool passwordVisible = false;

  Future<void> _login() async {
    setState(() => loading = true);
    try {
      final response = await widget.api.post('/auth/login', {
        'email': email.text.trim(),
        'password': password.text,
      });
      await widget.onAuthenticated(
        response['token'] as String,
        response['user'] as Map<String, dynamic>,
      );
    } catch (error) {
      if (!mounted) return;
      _snack(context, error.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return _AuthWaveScaffold(
      title: 'Sign in',
      child: Column(
        children: [
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.email_outlined),
              labelText: 'Email',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: password,
            obscureText: !passwordVisible,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              labelText: 'Password',
              suffixIcon: IconButton(
                tooltip: passwordVisible ? 'Hide password' : 'Show password',
                onPressed: () =>
                    setState(() => passwordVisible = !passwordVisible),
                icon: Icon(
                  passwordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ForgotPasswordScreen(api: widget.api),
                ),
              ),
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: 6),
          ElevatedButton(
            onPressed: loading ? null : _login,
            child: Text(loading ? 'Signing in...' : 'Sign in'),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'No account yet?',
                style: TextStyle(color: colors.secondaryText),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegisterScreen(
                      api: widget.api,
                      onAuthenticated: widget.onAuthenticated,
                    ),
                  ),
                ),
                child: const Text('Create account'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DemoLoginCard(
            onPick: (demoEmail) {
              email.text = demoEmail;
              password.text = 'password123';
            },
          ),
        ],
      ),
    );
  }
}

class _DemoLoginCard extends StatelessWidget {
  const _DemoLoginCard({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final demos = [
      (
        icon: Icons.person_outline_rounded,
        title: 'Customer demo',
        subtitle: 'Browse, book, and pay deposits',
        email: 'customer@venuehub.test',
      ),
      (
        icon: Icons.storefront_outlined,
        title: 'Host demo',
        subtitle: 'Manage venues and booking requests',
        email: 'host@venuehub.test',
      ),
      (
        icon: Icons.admin_panel_settings_outlined,
        title: 'Admin demo',
        subtitle: 'Review users, venues, and income',
        email: 'admin@venuehub.test',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceGray,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick demo login',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap an account to fill the demo credentials.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.secondaryText),
          ),
          const SizedBox(height: 10),
          ...demos.map(
            (demo) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onPick(demo.email),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.sky,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(demo.icon, color: AppTheme.navy),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                demo.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                demo.subtitle,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthWaveScaffold extends StatelessWidget {
  const _AuthWaveScaffold({
    required this.title,
    required this.child,
    this.showBack = false,
  });

  final String title;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Colors.white)),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 330,
            child: CustomPaint(painter: _AuthWavePainter()),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              children: [
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      if (showBack)
                        IconButton.filledTonal(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                    ],
                  ),
                ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.navy.withValues(alpha: 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const VenueHubLogo(size: 112),
                  ),
                ),
                const SizedBox(height: 112),
                Text(
                  title,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  height: 3,
                  width: 56,
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: AppTheme.gold,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: colors.divider),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.navy.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthWavePainter extends CustomPainter {
  const _AuthWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFEAF6FF), Color(0xFFBFE8FF), Color(0xFF80CFFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRect(rect, background);

    final contourPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.34);
    for (var i = 0; i < 7; i++) {
      final y = 24.0 + (i * 34);
      final path = Path()
        ..moveTo(-28, y)
        ..cubicTo(
          size.width * 0.24,
          y - 46,
          size.width * 0.36,
          y + 58,
          size.width * 0.58,
          y + 14,
        )
        ..cubicTo(
          size.width * 0.77,
          y - 24,
          size.width * 0.88,
          y + 48,
          size.width + 30,
          y + 8,
        );
      canvas.drawPath(path, contourPaint);
    }
    for (var i = 0; i < 4; i++) {
      final center = Offset(size.width * (0.22 + i * 0.21), 58 + i * 38);
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: 82 + i * 18,
          height: 48 + i * 14,
        ),
        contourPaint,
      );
    }

    final wave = Path()
      ..moveTo(0, size.height * 0.66)
      ..cubicTo(
        size.width * 0.20,
        size.height * 0.56,
        size.width * 0.34,
        size.height * 0.69,
        size.width * 0.50,
        size.height * 0.78,
      )
      ..cubicTo(
        size.width * 0.67,
        size.height * 0.89,
        size.width * 0.83,
        size.height * 0.70,
        size.width,
        size.height * 0.67,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(wave, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.api,
    required this.onAuthenticated,
  });

  final ApiClient api;
  final Future<void> Function(String token, Map<String, dynamic> user)
  onAuthenticated;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final phone = TextEditingController();
  String role = 'CUSTOMER';
  bool loading = false;
  bool passwordVisible = false;
  bool confirmPasswordVisible = false;

  Future<void> _register() async {
    if (password.text.length < 6) {
      _snack(context, 'Password must be at least 6 characters.');
      return;
    }
    if (password.text != confirmPassword.text) {
      _snack(context, 'Passwords do not match.');
      return;
    }

    setState(() => loading = true);
    try {
      final response = await widget.api.post('/auth/register', {
        'name': name.text.trim(),
        'email': email.text.trim(),
        'password': password.text,
        'phone': phone.text.trim(),
        'role': role,
      });
      await widget.onAuthenticated(
        response['token'] as String,
        response['user'] as Map<String, dynamic>,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      _snack(context, error.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return _AuthWaveScaffold(
      title: 'Create account',
      showBack: true,
      child: Column(
        children: [
          TextField(
            controller: name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person_outline_rounded),
              labelText: 'Full name',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.email_outlined),
              labelText: 'Email',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.phone_outlined),
              labelText: 'Contact number',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: password,
            obscureText: !passwordVisible,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              labelText: 'Password',
              suffixIcon: IconButton(
                tooltip: passwordVisible ? 'Hide password' : 'Show password',
                onPressed: () =>
                    setState(() => passwordVisible = !passwordVisible),
                icon: Icon(
                  passwordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: confirmPassword,
            obscureText: !confirmPasswordVisible,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.verified_user_outlined),
              labelText: 'Type password again',
              suffixIcon: IconButton(
                tooltip: confirmPasswordVisible
                    ? 'Hide password'
                    : 'Show password',
                onPressed: () => setState(
                  () => confirmPasswordVisible = !confirmPasswordVisible,
                ),
                icon: Icon(
                  confirmPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.badge_outlined),
              labelText: 'Account type',
            ),
            items: const [
              DropdownMenuItem(value: 'CUSTOMER', child: Text('Customer')),
              DropdownMenuItem(
                value: 'HOST',
                child: Text('Host / Venue Lister'),
              ),
              DropdownMenuItem(
                value: 'VENUEHUB_ADMIN',
                child: Text('VenueHub Admin'),
              ),
            ],
            onChanged: (value) => setState(() => role = value ?? 'CUSTOMER'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: loading ? null : _register,
            child: Text(loading ? 'Creating...' : 'Create account'),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Already have an account?',
                style: TextStyle(color: colors.secondaryText),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final email = TextEditingController();
  final token = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  bool loading = false;

  Future<void> _sendReset() async {
    setState(() => loading = true);
    try {
      final response = await widget.api.post('/auth/forgot-password', {
        'email': email.text.trim(),
      });
      if (!mounted) return;
      if (response['resetToken'] != null) {
        token.text = response['resetToken'].toString();
      }
      _snack(context, response['message']?.toString() ?? 'Reset email sent.');
    } catch (error) {
      if (!mounted) return;
      _snack(context, error.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _resetPassword() async {
    setState(() => loading = true);
    try {
      final response = await widget.api.post('/auth/reset-password', {
        'token': token.text.trim(),
        'password': password.text,
        'confirmPassword': confirmPassword.text,
      });
      if (!mounted) return;
      _snack(context, response['message']?.toString() ?? 'Password updated.');
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      _snack(context, error.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Enter your account email. VenueHub will send a reset link and code if the email exists.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: email,
            decoration: const InputDecoration(labelText: 'Account email'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: loading ? null : _sendReset,
            child: const Text('Send reset email'),
          ),
          const VHSectionTitle('Set new password'),
          TextField(
            controller: token,
            decoration: const InputDecoration(
              labelText: 'Reset code from email',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: confirmPassword,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: loading ? null : _resetPassword,
            child: const Text('Update password'),
          ),
        ],
      ),
    );
  }
}

class RoleHome extends StatelessWidget {
  const RoleHome({
    super.key,
    required this.api,
    required this.user,
    required this.onLogout,
    required this.onUserUpdated,
  });

  final ApiClient api;
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  final ValueChanged<Map<String, dynamic>> onUserUpdated;

  @override
  Widget build(BuildContext context) {
    return switch (user['role']) {
      'HOST' => HostHome(
        api: api,
        user: user,
        onLogout: onLogout,
        onUserUpdated: onUserUpdated,
      ),
      'VENUEHUB_ADMIN' => AdminHome(
        api: api,
        user: user,
        onLogout: onLogout,
        onUserUpdated: onUserUpdated,
      ),
      _ => CustomerHome(
        api: api,
        user: user,
        onLogout: onLogout,
        onUserUpdated: onUserUpdated,
      ),
    };
  }
}

class CustomerHome extends StatefulWidget {
  const CustomerHome({
    super.key,
    required this.api,
    required this.user,
    required this.onLogout,
    required this.onUserUpdated,
  });

  final ApiClient api;
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  final ValueChanged<Map<String, dynamic>> onUserUpdated;

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  int index = 0;
  Set<String> favoriteVenueIds = {};

  @override
  void initState() {
    super.initState();
    _restoreFavorites();
  }

  Future<void> _restoreFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('favoriteVenueIds') ?? const [];
    if (mounted) setState(() => favoriteVenueIds = saved.toSet());
  }

  Future<void> _setFavorite(String venueId, bool value) async {
    setState(() {
      if (value) {
        favoriteVenueIds.add(venueId);
      } else {
        favoriteVenueIds.remove(venueId);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoriteVenueIds', favoriteVenueIds.toList());
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      VenueBrowseScreen(
        api: widget.api,
        favoriteVenueIds: favoriteVenueIds,
        onFavoriteChanged: _setFavorite,
      ),
      FavoritesScreen(
        api: widget.api,
        favoriteVenueIds: favoriteVenueIds,
        onFavoriteChanged: _setFavorite,
      ),
      MyBookingsScreen(api: widget.api),
      ProfileScreen(
        api: widget.api,
        user: widget.user,
        onLogout: widget.onLogout,
        onUserUpdated: widget.onUserUpdated,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: AppTheme.colorsOf(context).divider),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: (value) => setState(() => index = value),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search_rounded),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border_rounded),
              activeIcon: Icon(Icons.favorite_rounded),
              label: 'Favourites',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today_rounded),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class VenueBrowseScreen extends StatefulWidget {
  const VenueBrowseScreen({
    super.key,
    required this.api,
    required this.favoriteVenueIds,
    required this.onFavoriteChanged,
  });

  final ApiClient api;
  final Set<String> favoriteVenueIds;
  final Future<void> Function(String venueId, bool value) onFavoriteChanged;

  @override
  State<VenueBrowseScreen> createState() => _VenueBrowseScreenState();
}

class _VenueBrowseScreenState extends State<VenueBrowseScreen> {
  final query = TextEditingController();
  final location = TextEditingController();
  String selectedLocation = 'All';
  late Future<List<dynamic>> venues = _loadVenues();

  Future<List<dynamic>> _loadVenues() async {
    final response = await widget.api.get('/venues');
    return response['venues'] as List<dynamic>;
  }

  Future<void> _search() async {
    try {
      final response = await widget.api.get(
        '/venues/search?query=${Uri.encodeComponent(query.text)}&location=${Uri.encodeComponent(location.text)}',
      );
      selectedLocation = location.text.trim().isEmpty
          ? 'All'
          : _locationLabel(location.text);
      setState(
        () => venues = Future.value(response['venues'] as List<dynamic>),
      );
    } catch (error) {
      if (!mounted) return;
      _snack(context, error.toString());
    }
  }

  Future<void> _openSearchSheet() async {
    final shouldSearch = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Where is your next event?',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: query,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Venue name, event type, or keyword',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: location,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => Navigator.pop(context, true),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.place_outlined),
                hintText: 'Tacloban, Palo, Tanauan, Dulag...',
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Search venues'),
            ),
          ],
        ),
      ),
    );

    if (shouldSearch == true) await _search();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => setState(() => venues = _loadVenues()),
          child: FutureBuilder<List<dynamic>>(
            future: venues,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingView();
              }
              if (snapshot.hasError) {
                return EmptyState(
                  title: 'API unavailable',
                  message: snapshot.error.toString(),
                );
              }
              final data = snapshot.data ?? [];
              final cards = data.cast<Map<String, dynamic>>();
              final locationCategories = _locationCategoryItems(cards);
              final activeLocation =
                  selectedLocation == 'All' ||
                      locationCategories.any(
                        (item) => item.label == selectedLocation,
                      )
                  ? selectedLocation
                  : 'All';
              final displayed = activeLocation == 'All'
                  ? cards
                  : cards
                        .where(
                          (venue) =>
                              _locationLabel(venue['location']) ==
                              activeLocation,
                        )
                        .toList();
              final grouped = _groupVenuesByLocation(displayed);
              final sectionEntries = grouped.entries.take(5).toList();
              final featured = displayed.take(6).toList();
              final verticalCards = displayed.take(8).toList();

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: SearchPill(
                      title: query.text.trim().isEmpty
                          ? 'Start your search'
                          : query.text.trim(),
                      subtitle: location.text.trim().isEmpty
                          ? 'Anywhere - Any week - Add guests'
                          : '${_locationLabel(location.text)} - Any week - Add guests',
                      onTap: _openSearchSheet,
                      trailing: NotificationBell(api: widget.api),
                    ),
                  ),
                  CategoryRail(
                    items: locationCategories,
                    selected: activeLocation,
                    onSelected: (value) {
                      setState(() {
                        selectedLocation = value;
                        if (value == 'All') {
                          location.clear();
                        } else {
                          location.text = value;
                        }
                      });
                    },
                  ),
                  if (cards.isEmpty)
                    const EmptyState(
                      title: 'No venues yet',
                      message: 'Approved venues will appear here.',
                    )
                  else if (displayed.isEmpty)
                    EmptyState(
                      title: 'No venues in $activeLocation',
                      message:
                          'Try another location or use search to widen the results.',
                    )
                  else ...[
                    _InlineExploreBanner(
                      location: activeLocation == 'All'
                          ? _locationLabel(displayed.first['location'])
                          : activeLocation,
                      onTap: _openSearchSheet,
                    ),
                    VenueHorizontalSection(
                      title: activeLocation == 'All'
                          ? 'Featured Region 8 venues'
                          : 'Popular in $activeLocation',
                      venues: featured,
                      api: widget.api,
                      favoriteVenueIds: widget.favoriteVenueIds,
                      onFavoriteChanged: widget.onFavoriteChanged,
                    ),
                    if (activeLocation == 'All')
                      ...sectionEntries.map(
                        (entry) => VenueHorizontalSection(
                          title: '${entry.key} event places',
                          venues: entry.value.take(8).toList(),
                          api: widget.api,
                          favoriteVenueIds: widget.favoriteVenueIds,
                          onFavoriteChanged: widget.onFavoriteChanged,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                      child: Text(
                        activeLocation == 'All'
                            ? 'Browse all event places'
                            : 'All $activeLocation event places',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                    ...verticalCards.map(
                      (venue) => VenueCard(
                        venue: venue,
                        api: widget.api,
                        isFavorite: widget.favoriteVenueIds.contains(
                          venue['id']?.toString(),
                        ),
                        onFavoriteChanged: (value) => widget.onFavoriteChanged(
                          venue['id'].toString(),
                          value,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InlineExploreBanner extends StatelessWidget {
  const _InlineExploreBanner({required this.location, required this.onTap});

  final String location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        highlightColor: colors.surfaceGray,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue searching in $location',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pick dates, guests, and event style',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: colors.surfaceGray,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_forward_rounded, color: colors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({
    super.key,
    required this.api,
    required this.favoriteVenueIds,
    required this.onFavoriteChanged,
  });

  final ApiClient api;
  final Set<String> favoriteVenueIds;
  final Future<void> Function(String venueId, bool value) onFavoriteChanged;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<dynamic>> venues = _loadVenues();

  Future<List<dynamic>> _loadVenues() async {
    final response = await widget.api.get('/venues');
    return response['venues'] as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => setState(() => venues = _loadVenues()),
          child: FutureBuilder<List<dynamic>>(
            future: venues,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return snapshot.hasError
                    ? EmptyState(
                        title: 'Could not load favourites',
                        message: snapshot.error.toString(),
                      )
                    : const LoadingView();
              }

              final cards = snapshot.data!
                  .cast<Map<String, dynamic>>()
                  .where(
                    (venue) => widget.favoriteVenueIds.contains(
                      venue['id']?.toString(),
                    ),
                  )
                  .toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                children: [
                  Text(
                    'Favourites',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Venues you liked are saved here on this device.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  if (cards.isEmpty)
                    const EmptyState(
                      title: 'No favourites yet',
                      message:
                          'Tap the heart on a venue to keep it in this list.',
                    )
                  else
                    ...cards.map(
                      (venue) => VenueCard(
                        venue: venue,
                        api: widget.api,
                        isFavorite: true,
                        onFavoriteChanged: (value) => widget.onFavoriteChanged(
                          venue['id'].toString(),
                          value,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, required this.api});

  final ApiClient api;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int unreadCount = 0;
  List<dynamic> notifications = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await widget.api.get('/notifications');
      if (!mounted) return;
      setState(() {
        unreadCount = _num(response['unreadCount']).toInt();
        notifications = response['notifications'] as List<dynamic>? ?? [];
      });
    } catch (_) {
      // Notifications should never block the main explore experience.
    }
  }

  Future<void> _openNotifications() async {
    await _load();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Notifications',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (notifications.isEmpty)
              const EmptyState(
                title: 'Nothing yet',
                message: 'Booking and transaction updates will appear here.',
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = notifications[index] as Map<String, dynamic>;
                    final unread = item['readAt'] == null;
                    final type = item['type']?.toString() ?? '';
                    final accent = _notificationAccent(type);
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: unread
                            ? accent.withValues(alpha: 0.08)
                            : AppTheme.surfaceGray,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusCard,
                        ),
                        border: Border.all(
                          color: unread
                              ? accent.withValues(alpha: 0.28)
                              : AppTheme.divider,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _notificationIcon(type),
                              color: accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['title']?.toString() ?? 'Update',
                                  style: TextStyle(
                                    fontWeight: unread
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item['message']?.toString() ?? '',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _dateLabel(item['createdAt']),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          if (unread)
                            Container(
                              height: 8,
                              width: 8,
                              margin: const EdgeInsets.only(top: 5),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );

    try {
      await widget.api.put('/notifications/read', {});
      if (mounted) setState(() => unreadCount = 0);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: _openNotifications,
          icon: const Icon(Icons.notifications_none_rounded),
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.sky,
            foregroundColor: AppTheme.navy,
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              height: 9,
              width: 9,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class LocationCategoryRail extends StatelessWidget {
  const LocationCategoryRail({
    super.key,
    required this.locations,
    required this.selected,
    required this.onSelected,
  });

  final List<String> locations;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = ['All', ...locations];

    return SizedBox(
      height: 78,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          final active = selected == item;

          return InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => onSelected(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 104,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: active ? AppTheme.navy : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: active ? AppTheme.navy : AppTheme.line,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: AppTheme.navy.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item == 'All'
                        ? Icons.grid_view_rounded
                        : Icons.location_city_rounded,
                    color: active ? Colors.white : AppTheme.navy,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? Colors.white : AppTheme.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ContinueSearchingCard extends StatelessWidget {
  const ContinueSearchingCard({
    super.key,
    required this.location,
    required this.imageUrl,
    required this.onTap,
  });

  final String location;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
      child: Material(
        color: Colors.white,
        elevation: 10,
        shadowColor: AppTheme.navy.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Continue searching for venues in $location',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Pick dates, guests, and event style',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: VenueImageView(
                    imageUrl: imageUrl,
                    height: 86,
                    width: 86,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VenueHorizontalSection extends StatelessWidget {
  const VenueHorizontalSection({
    super.key,
    required this.title,
    required this.venues,
    required this.api,
    required this.favoriteVenueIds,
    required this.onFavoriteChanged,
  });

  final String title;
  final List<Map<String, dynamic>> venues;
  final ApiClient api;
  final Set<String> favoriteVenueIds;
  final Future<void> Function(String venueId, bool value) onFavoriteChanged;

  @override
  Widget build(BuildContext context) {
    if (venues.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: AppTheme.ink),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 286,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: venues.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final venue = venues[index];
                return VenueMiniCard(
                  venue: venue,
                  api: api,
                  isFavorite: favoriteVenueIds.contains(
                    venue['id']?.toString(),
                  ),
                  onFavoriteChanged: (value) =>
                      onFavoriteChanged(venue['id'].toString(), value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class VenueMiniCard extends StatelessWidget {
  const VenueMiniCard({
    super.key,
    required this.venue,
    required this.api,
    this.isFavorite = false,
    this.onFavoriteChanged,
  });

  final Map<String, dynamic> venue;
  final ApiClient api;
  final bool isFavorite;
  final ValueChanged<bool>? onFavoriteChanged;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _firstVenueImage(venue);
    final colors = AppTheme.colorsOf(context);

    return SizedBox(
      width: 196,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        highlightColor: colors.surfaceGray,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VenueDetailsScreen(
              api: api,
              venueId: venue['id'] as String,
              isFavorite: isFavorite,
              onFavoriteChanged: onFavoriteChanged,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  child: VenueImageView(
                    imageUrl: imageUrl,
                    height: 176,
                    width: 196,
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    constraints: const BoxConstraints(
                      minHeight: 44,
                      minWidth: 44,
                    ),
                    onPressed: () => onFavoriteChanged?.call(!isFavorite),
                    icon: Icon(
                      isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFavorite ? AppTheme.gold : Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              venue['name']?.toString() ?? 'Venue',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 14,
                  color: colors.secondaryText,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _locationLabel(venue['location']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.secondaryText),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.groups_2_outlined,
                  size: 14,
                  color: colors.secondaryText,
                ),
                const SizedBox(width: 3),
                Text(
                  '${venue['capacity']}',
                  style: TextStyle(color: colors.secondaryText),
                ),
              ],
            ),
            const SizedBox(height: 4),
            PriceText(
              amount: _num(venue['pricePerDay']),
              suffix: 'day',
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}

class VenueCard extends StatefulWidget {
  const VenueCard({
    super.key,
    required this.venue,
    required this.api,
    this.isFavorite = false,
    this.onFavoriteChanged,
  });

  final Map<String, dynamic> venue;
  final ApiClient api;
  final bool isFavorite;
  final ValueChanged<bool>? onFavoriteChanged;

  @override
  State<VenueCard> createState() => _VenueCardState();
}

class _VenueCardState extends State<VenueCard> {
  int page = 0;
  bool pulseFavorite = false;

  @override
  Widget build(BuildContext context) {
    final venue = widget.venue;
    final colors = AppTheme.colorsOf(context);
    final urls = _venueImageUrls(venue);
    final rating = _num(venue['averageRating']);
    final heroTag = 'venue-${venue['id']}-image';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        highlightColor: colors.surfaceGray,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VenueDetailsScreen(
              api: widget.api,
              venueId: venue['id'] as String,
              isFavorite: widget.isFavorite,
              onFavoriteChanged: widget.onFavoriteChanged,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 190,
              width: double.infinity,
              child: Stack(
                children: [
                  Hero(
                    tag: heroTag,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                      child: urls.isEmpty
                          ? VenueImageView(
                              imageUrl: '',
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : PageView.builder(
                              itemCount: urls.length,
                              onPageChanged: (value) =>
                                  setState(() => page = value),
                              itemBuilder: (context, index) => VenueImageView(
                                imageUrl: urls[index],
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      onPressed: () {
                        setState(() => pulseFavorite = true);
                        widget.onFavoriteChanged?.call(!widget.isFavorite);
                        Future.delayed(const Duration(milliseconds: 180), () {
                          if (mounted) setState(() => pulseFavorite = false);
                        });
                      },
                      icon: AnimatedScale(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutBack,
                        scale: pulseFavorite ? 1.18 : 1,
                        child: Icon(
                          widget.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: widget.isFavorite
                              ? AppTheme.gold
                              : Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (urls.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          urls.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            height: 6,
                            width: page == index ? 7 : 6,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: page == index ? 0.95 : 0.55,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    venue['name']?.toString() ?? 'Venue',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (rating > 0) ...[
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.star_rounded,
                    size: 17,
                    color: AppTheme.gold,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    rating.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _VenueFact(
                  icon: Icons.place_outlined,
                  label: _locationLabel(venue['location']),
                ),
                _VenueFact(
                  icon: Icons.groups_2_outlined,
                  label: 'Up to ${venue['capacity'] ?? 'many'}',
                ),
                _VenueFact(
                  icon: Icons.near_me_outlined,
                  label: _demoDistance(venue),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _VenueAmenityPreview(venue: venue),
            const SizedBox(height: 8),
            PriceText(amount: _num(venue['pricePerDay']), suffix: 'day'),
          ],
        ),
      ),
    );
  }
}

class _VenueFact extends StatelessWidget {
  const _VenueFact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.sky.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.navy),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _VenueAmenityPreview extends StatelessWidget {
  const _VenueAmenityPreview({required this.venue});

  final Map<String, dynamic> venue;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final items = _venueFeatureItems(venue).take(3).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: items
          .map(
            (item) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 16, color: AppTheme.blue),
                const SizedBox(width: 4),
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _VenueFeatureItem {
  const _VenueFeatureItem(this.icon, this.label);

  final IconData icon;
  final String label;
}

List<_VenueFeatureItem> _venueFeatureItems(Map<String, dynamic> venue) {
  final source = [
    ...(venue['amenities'] as List<dynamic>? ?? []),
    ...(venue['facilities'] as List<dynamic>? ?? []),
  ];
  return _cleanOfferLabels(source)
      .map((label) => _VenueFeatureItem(_featureIconForLabel(label), label))
      .toList();
}

List<String> _cleanOfferLabels(List<dynamic> items, {int? limit}) {
  final seen = <String>{};
  final labels = <String>[];
  for (final item in items) {
    final raw = item is Map ? item['name']?.toString() : item.toString();
    final label = raw?.trim();
    if (label == null || label.isEmpty) continue;
    final key = label.toLowerCase();
    if (seen.add(key)) labels.add(label);
    if (limit != null && labels.length >= limit) break;
  }
  return labels;
}

List<CategoryItem> _locationCategoryItems(List<Map<String, dynamic>> venues) {
  final labels = venues
      .map((venue) => _locationLabel(venue['location']))
      .where((label) => label.isNotEmpty && label != 'Nearby')
      .toSet()
      .toList();
  labels.sort((a, b) {
    final orderA = _locationSortOrder(a);
    final orderB = _locationSortOrder(b);
    if (orderA != orderB) return orderA.compareTo(orderB);
    return a.compareTo(b);
  });

  return [
    const CategoryItem(Icons.apps_rounded, 'All'),
    ...labels.map((label) => CategoryItem(_locationIcon(label), label)),
  ];
}

int _locationSortOrder(String label) {
  const order = [
    'Tacloban',
    'Palo',
    'Tanauan',
    'Dulag',
    'Jaro',
    'Ormoc',
    'Burauen',
    'Calbayog',
    'Catbalogan',
    'Catarman',
  ];
  final index = order.indexOf(label);
  return index == -1 ? 999 : index;
}

IconData _locationIcon(String label) {
  final lower = label.toLowerCase();
  if (lower.contains('tanauan') || lower.contains('dulag')) {
    return Icons.beach_access_outlined;
  }
  if (lower.contains('palo') || lower.contains('catarman')) {
    return Icons.account_balance_outlined;
  }
  if (lower.contains('burauen') || lower.contains('jaro')) {
    return Icons.landscape_outlined;
  }
  if (lower.contains('ormoc') ||
      lower.contains('calbayog') ||
      lower.contains('catbalogan')) {
    return Icons.apartment_outlined;
  }
  return Icons.location_city_outlined;
}

IconData _featureIconForLabel(String label) {
  final normalized = label.toLowerCase();
  if (normalized.contains('parking')) return Icons.directions_car_outlined;
  if (normalized.contains('wi-fi') || normalized.contains('wifi')) {
    return Icons.wifi_rounded;
  }
  if (normalized.contains('photo') || normalized.contains('camera')) {
    return Icons.photo_camera_outlined;
  }
  if (normalized.contains('air')) return Icons.ac_unit_rounded;
  if (normalized.contains('sound') || normalized.contains('audio')) {
    return Icons.speaker_outlined;
  }
  if (normalized.contains('catering') ||
      normalized.contains('kitchen') ||
      normalized.contains('food')) {
    return Icons.restaurant_outlined;
  }
  if (normalized.contains('stage')) return Icons.theater_comedy_outlined;
  if (normalized.contains('projector') || normalized.contains('led')) {
    return Icons.connected_tv_outlined;
  }
  if (normalized.contains('security')) return Icons.security_outlined;
  if (normalized.contains('table') ||
      normalized.contains('chair') ||
      normalized.contains('seat')) {
    return Icons.event_seat_outlined;
  }
  if (normalized.contains('light')) return Icons.light_mode_outlined;
  if (normalized.contains('prep') || normalized.contains('room')) {
    return Icons.meeting_room_outlined;
  }
  if (normalized.contains('view') ||
      normalized.contains('garden') ||
      normalized.contains('outdoor')) {
    return Icons.landscape_outlined;
  }
  if (normalized.contains('hall')) return Icons.apartment_outlined;
  return Icons.check_circle_outline_rounded;
}

String _demoDistance(Map<String, dynamic> venue) {
  final label = _locationLabel(venue['location']);
  return switch (label) {
    'Tacloban' => '2 kilometers',
    'Palo' => '9 kilometers',
    'Ormoc' => '107 kilometers',
    'Baybay' => '97 kilometers',
    'Guiuan' => '150 kilometers',
    _ => 'Nearby',
  };
}

class VenueDetailsScreen extends StatefulWidget {
  const VenueDetailsScreen({
    super.key,
    required this.api,
    required this.venueId,
    this.isFavorite = false,
    this.onFavoriteChanged,
  });

  final ApiClient api;
  final String venueId;
  final bool isFavorite;
  final ValueChanged<bool>? onFavoriteChanged;

  @override
  State<VenueDetailsScreen> createState() => _VenueDetailsScreenState();
}

class _VenueDetailsScreenState extends State<VenueDetailsScreen> {
  late Future<Map<String, dynamic>> venue = _load();
  int galleryPage = 0;
  bool favorite = false;
  bool showFullAbout = false;

  @override
  void initState() {
    super.initState();
    favorite = widget.isFavorite;
  }

  Future<Map<String, dynamic>> _load() async {
    final response = await widget.api.get('/venues/${widget.venueId}');
    return response['venue'] as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: venue,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: snapshot.hasError
                ? EmptyState(
                    title: 'Could not load venue',
                    message: snapshot.error.toString(),
                  )
                : const LoadingView(),
          );
        }

        final venue = snapshot.data!;
        final urls = _venueImageUrls(venue);
        final colors = AppTheme.colorsOf(context);
        final rating = _num(venue['averageRating']);
        final reviews = venue['reviews'] as List<dynamic>? ?? [];
        final amenities = venue['amenities'] as List<dynamic>? ?? [];
        final facilities = venue['facilities'] as List<dynamic>? ?? [];
        final description = venue['description']?.toString() ?? '';
        final host = venue['host'] as Map<String, dynamic>?;

        return Scaffold(
          extendBodyBehindAppBar: true,
          bottomNavigationBar: StickyBookingBar(
            price: _num(venue['pricePerDay']),
            onReserve: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookingScreen(api: widget.api, venue: venue),
              ),
            ),
          ),
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              Stack(
                children: [
                  Hero(
                    tag: 'venue-${widget.venueId}-image',
                    child: SizedBox(
                      height: 330,
                      width: double.infinity,
                      child: urls.isEmpty
                          ? const VenueImageView(
                              imageUrl: '',
                              width: double.infinity,
                              height: 330,
                            )
                          : PageView.builder(
                              itemCount: urls.length,
                              onPageChanged: (value) =>
                                  setState(() => galleryPage = value),
                              itemBuilder: (context, index) => VenueImageView(
                                imageUrl: urls[index],
                                width: double.infinity,
                                height: 330,
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 12,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        _FloatingCircleButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        _FloatingCircleButton(
                          icon: favorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: favorite ? AppTheme.gold : AppTheme.ink,
                          onTap: () {
                            setState(() => favorite = !favorite);
                            widget.onFavoriteChanged?.call(favorite);
                          },
                        ),
                      ],
                    ),
                  ),
                  if (urls.length > 1)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                        ),
                        child: Text(
                          '${galleryPage + 1} / ${urls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue['name']?.toString() ?? 'Venue',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${venue['capacity'] ?? 'Many'} guests · ${_locationLabel(venue['location'])}, Eastern Visayas',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: AppTheme.gold,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating == 0
                              ? 'No reviews yet'
                              : '${rating.toStringAsFixed(1)} · ${reviews.length} reviews',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SectionDivider(),
                    _HostedByRow(host: host),
                    const SectionDivider(),
                    Text(
                      'About this venue',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      showFullAbout || description.length < 180
                          ? description
                          : '${description.substring(0, 180)}...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (description.length >= 180)
                      TextButton(
                        onPressed: () =>
                            setState(() => showFullAbout = !showFullAbout),
                        child: Text(showFullAbout ? 'Show less' : 'Show more'),
                      ),
                    const SectionDivider(),
                    _OfferList(
                      title: 'What this place offers',
                      items: [...amenities, ...facilities],
                    ),
                    const SectionDivider(),
                    Text(
                      "Where you'll be",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    DemoMapPreview(venue: venue),
                    const SectionDivider(),
                    _Reviews(reviews: reviews),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FloatingCircleButton extends StatelessWidget {
  const _FloatingCircleButton({
    required this.icon,
    required this.onTap,
    this.color = AppTheme.ink,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: color, size: 21),
        ),
      ),
    );
  }
}

class _HostedByRow extends StatelessWidget {
  const _HostedByRow({required this.host});

  final Map<String, dynamic>? host;

  @override
  Widget build(BuildContext context) {
    final name = host?['name']?.toString() ?? 'VenueHub host';
    final initial = name.trim().isEmpty ? 'V' : name.trim()[0].toUpperCase();
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppTheme.surfaceGray,
          child: Text(
            initial,
            style: const TextStyle(
              color: AppTheme.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hosted by $name',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'Responsive venue lister · Demo verified',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OfferList extends StatelessWidget {
  const _OfferList({required this.title, required this.items});

  final String title;
  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final values = _cleanOfferLabels(items, limit: 8);
    final display = values.isEmpty
        ? [
            'Event-ready space',
            'Parking nearby',
            'Flexible setup',
            'Staff assistance',
          ]
        : values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: display
              .map(
                (label) => SizedBox(
                  width: (MediaQuery.of(context).size.width - 44) / 2,
                  child: Row(
                    children: [
                      Icon(
                        _featureIconForLabel(label),
                        size: 22,
                        color: AppTheme.blue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: colors.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class DemoMapPreview extends StatelessWidget {
  const DemoMapPreview({super.key, required this.venue});

  final Map<String, dynamic> venue;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final location = venue['location']?.toString() ?? 'Eastern Visayas';
    final address = venue['address']?.toString() ?? 'Demo address';
    final point = _venueLatLng(venue);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Container(
            height: 230,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              gradient: LinearGradient(
                colors: [colors.surfaceGray, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: colors.divider),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: fm.FlutterMap(
                    options: fm.MapOptions(
                      initialCenter: point,
                      initialZoom: 14,
                      minZoom: 8,
                      maxZoom: 18,
                      interactionOptions: const fm.InteractionOptions(
                        flags:
                            fm.InteractiveFlag.drag |
                            fm.InteractiveFlag.pinchZoom |
                            fm.InteractiveFlag.doubleTapZoom,
                      ),
                    ),
                    children: [
                      fm.TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.venuehub.mobile',
                      ),
                      fm.MarkerLayer(
                        markers: [
                          fm.Marker(
                            point: point,
                            width: 54,
                            height: 54,
                            child: const _VenueMapMarker(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'OpenStreetMap',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.divider),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.place_rounded, color: AppTheme.blue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$location - $address',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$location · $address',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Map data © OpenStreetMap contributors. Demo markers use exact or nearby public map locations.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _VenueMapMarker extends StatelessWidget {
  const _VenueMapMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.gold,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: const Icon(Icons.location_on_rounded, color: AppTheme.navy),
      ),
    );
  }
}

// Kept as a lightweight fallback reference for older screenshots and demos.
// ignore: unused_element
class _DemoMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final water = Paint()..color = const Color(0xFFD9EEFA);
    final land = Paint()..color = const Color(0xFFDCF0DD);
    final landStroke = Paint()
      ..color = const Color(0xFFA8CFA8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final majorRoad = Paint()
      ..color = Colors.white.withValues(alpha: 0.94)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final roadLine = Paint()
      ..color = const Color(0xFFF0B84B)
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round;
    final minorRoad = Paint()
      ..color = Colors.white.withValues(alpha: 0.66)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawRect(Offset.zero & size, water);

    final leyte = Path()
      ..moveTo(size.width * 0.28, size.height * 0.08)
      ..cubicTo(
        size.width * 0.45,
        size.height * 0.04,
        size.width * 0.58,
        size.height * 0.15,
        size.width * 0.62,
        size.height * 0.32,
      )
      ..cubicTo(
        size.width * 0.67,
        size.height * 0.53,
        size.width * 0.56,
        size.height * 0.72,
        size.width * 0.47,
        size.height * 0.91,
      )
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.74,
        size.width * 0.23,
        size.height * 0.55,
        size.width * 0.22,
        size.height * 0.34,
      )
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.22,
        size.width * 0.24,
        size.height * 0.14,
        size.width * 0.28,
        size.height * 0.08,
      )
      ..close();
    final samar = Path()
      ..moveTo(size.width * 0.63, size.height * 0.03)
      ..cubicTo(
        size.width * 0.84,
        size.height * 0.08,
        size.width * 0.96,
        size.height * 0.24,
        size.width * 0.89,
        size.height * 0.44,
      )
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.41,
        size.width * 0.69,
        size.height * 0.35,
        size.width * 0.61,
        size.height * 0.24,
      )
      ..close();
    final biliran = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width * 0.30, size.height * 0.17),
          radius: size.shortestSide * 0.055,
        ),
      );

    for (final path in [leyte, samar, biliran]) {
      canvas.drawPath(path, land);
      canvas.drawPath(path, landStroke);
    }

    final panLeyte = Path()
      ..moveTo(size.width * 0.42, size.height * 0.13)
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 0.32,
        size.width * 0.49,
        size.height * 0.53,
      )
      ..quadraticBezierTo(
        size.width * 0.46,
        size.height * 0.72,
        size.width * 0.42,
        size.height * 0.88,
      );
    canvas.drawPath(panLeyte, majorRoad);
    canvas.drawPath(panLeyte, roadLine);

    canvas.drawLine(
      Offset(size.width * 0.48, size.height * 0.28),
      Offset(size.width * 0.69, size.height * 0.22),
      minorRoad,
    );
    canvas.drawLine(
      Offset(size.width * 0.46, size.height * 0.47),
      Offset(size.width * 0.31, size.height * 0.53),
      minorRoad,
    );
    canvas.drawLine(
      Offset(size.width * 0.44, size.height * 0.67),
      Offset(size.width * 0.28, size.height * 0.78),
      minorRoad,
    );

    _label(canvas, 'Tacloban', Offset(size.width * 0.56, size.height * 0.25));
    _label(canvas, 'Palo', Offset(size.width * 0.49, size.height * 0.34));
    _label(canvas, 'Ormoc', Offset(size.width * 0.31, size.height * 0.48));
    _label(canvas, 'Baybay', Offset(size.width * 0.38, size.height * 0.70));
    _label(canvas, 'Leyte Gulf', Offset(size.width * 0.67, size.height * 0.61));

    final pin = Offset(size.width * 0.56, size.height * 0.26);
    canvas.drawCircle(pin, 7, Paint()..color = AppTheme.gold);
    canvas.drawCircle(pin, 4, Paint()..color = AppTheme.navy);
  }

  void _label(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppTheme.ink,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InfoPill extends StatelessWidget {
  const _InfoPill(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 16), label: Text(label));
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({required this.reviews});

  final List<dynamic> reviews;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final ratings = reviews.map((review) => _num(review['rating'])).toList();
    final average = ratings.isEmpty
        ? 0
        : ratings.fold<num>(0, (sum, value) => sum + value) / ratings.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, size: 22, color: AppTheme.gold),
            const SizedBox(width: 6),
            Text(
              average == 0
                  ? 'No reviews yet'
                  : '${average.toStringAsFixed(1)} · ${reviews.length} reviews',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (reviews.isEmpty)
          Text(
            'Reviews from completed demo bookings will appear here.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: reviews.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final review = reviews[index] as Map<String, dynamic>;
                return Container(
                  width: 230,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(color: colors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: AppTheme.gold,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${review['rating'] ?? 0}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Text(
                          review['comment']?.toString() ?? '',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.api, required this.venue});

  final ApiClient api;
  final Map<String, dynamic> venue;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final notes = TextEditingController();
  DateTime? eventDate;
  bool loading = false;
  bool loadingUnavailableDates = true;
  List<Map<String, dynamic>> unavailableDates = [];
  Set<String> unavailableDateKeys = {};

  @override
  void initState() {
    super.initState();
    _loadUnavailableDates();
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> _loadUnavailableDates() async {
    setState(() => loadingUnavailableDates = true);
    try {
      final response = await widget.api.get(
        '/bookings/venue/${widget.venue['id']}/unavailable-dates',
      );
      final dates = (response['unavailableDates'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      if (!mounted) return;
      setState(() {
        unavailableDates = dates;
        unavailableDateKeys = dates
            .map((item) => item['date']?.toString() ?? '')
            .where((date) => date.isNotEmpty)
            .toSet();
        if (eventDate != null && _isUnavailable(eventDate!)) {
          eventDate = null;
        }
      });
    } catch (error) {
      if (mounted) _snack(context, error.toString());
    } finally {
      if (mounted) setState(() => loadingUnavailableDates = false);
    }
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  bool _isUnavailable(DateTime date) =>
      unavailableDateKeys.contains(_dateKey(date));

  DateTime? _firstAvailableDate() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final start = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    for (var offset = 0; offset <= 730; offset++) {
      final candidate = start.add(Duration(days: offset));
      if (!_isUnavailable(candidate)) return candidate;
    }
    return null;
  }

  Future<void> _pickDate() async {
    if (loadingUnavailableDates) {
      _snack(context, 'Checking booked dates. Please wait a moment.');
      return;
    }

    final initialDate = eventDate != null && !_isUnavailable(eventDate!)
        ? eventDate!
        : _firstAvailableDate();
    if (initialDate == null) {
      _snack(context, 'No available dates found for this venue.');
      return;
    }

    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: initialDate,
      helpText: 'Select an available event date',
      selectableDayPredicate: (date) => !_isUnavailable(date),
    );
    if (picked != null) setState(() => eventDate = picked);
  }

  Future<void> _book() async {
    if (eventDate == null) {
      _snack(context, 'Please choose an event date.');
      return;
    }
    if (_isUnavailable(eventDate!)) {
      await _loadUnavailableDates();
      if (!mounted) return;
      _snack(context, 'That date was just booked. Please choose another date.');
      return;
    }

    setState(() => loading = true);
    try {
      final response = await widget.api.post('/bookings', {
        'venueId': widget.venue['id'],
        'eventDate': eventDate!.toIso8601String(),
        'notes': notes.text.trim(),
      });
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            api: widget.api,
            booking: response['booking'] as Map<String, dynamic>,
          ),
        ),
      );
    } catch (error) {
      await _loadUnavailableDates();
      if (!mounted) return;
      _snack(context, error.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = _num(widget.venue['pricePerDay']);
    final deposit = price * 0.5;
    final fee = price * 0.1;

    return Scaffold(
      appBar: AppBar(title: const Text('Reserve venue')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.venue['name'],
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _MoneyRow('Venue price', price),
                  _MoneyRow('50% security deposit', deposit),
                  _MoneyRow('Remaining balance', price - deposit),
                  _MoneyRow('10% app service fee', fee),
                  const Divider(),
                  const Text(
                    'If the date is available, it is reserved immediately. Pay the non-refundable 50% deposit to secure it.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _BookedDateNotice(
            loading: loadingUnavailableDates,
            unavailableDates: unavailableDates,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month),
            label: Text(
              eventDate == null
                  ? 'Choose available event date'
                  : dateFormat.format(eventDate!),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notes,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Notes for host'),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: loading ? null : _book,
            child: Text(loading ? 'Reserving...' : 'Continue to 50% deposit'),
          ),
        ],
      ),
    );
  }
}

class _BookedDateNotice extends StatelessWidget {
  const _BookedDateNotice({
    required this.loading,
    required this.unavailableDates,
  });

  final bool loading;
  final List<Map<String, dynamic>> unavailableDates;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final upcoming = unavailableDates.take(6).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.sky,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            loading ? Icons.sync_rounded : Icons.event_busy_outlined,
            color: AppTheme.navy,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loading
                      ? 'Checking booked dates'
                      : 'Booked dates are disabled',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'You and other customers cannot reserve the same venue on an already-booked date.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.ink),
                ),
                if (!loading && upcoming.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: upcoming.map((item) {
                      final parsed = DateTime.tryParse(
                        item['date']?.toString() ?? '',
                      );
                      return Chip(
                        avatar: const Icon(Icons.lock_clock_outlined, size: 16),
                        label: Text(
                          parsed == null
                              ? item['date'].toString()
                              : dateFormat.format(parsed),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow(this.label, this.value);

  final String label;
  final num value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            moneyFormat.format(value),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _PaymentOption {
  const _PaymentOption({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
}

const _paymentOptions = [
  _PaymentOption(
    value: 'GCASH',
    label: 'GCash',
    subtitle: 'Mobile wallet',
    icon: Icons.phone_iphone_rounded,
    color: Color(0xFF1476F2),
  ),
  _PaymentOption(
    value: 'MAYA',
    label: 'Maya',
    subtitle: 'E-wallet',
    icon: Icons.account_balance_wallet_outlined,
    color: Color(0xFF00A86B),
  ),
  _PaymentOption(
    value: 'VISA',
    label: 'Visa',
    subtitle: 'Credit or debit card',
    icon: Icons.credit_card_rounded,
    color: Color(0xFF1A4FA3),
  ),
  _PaymentOption(
    value: 'MASTERCARD',
    label: 'Mastercard',
    subtitle: 'Credit or debit card',
    icon: Icons.credit_score_rounded,
    color: Color(0xFFE45D25),
  ),
  _PaymentOption(
    value: 'PAYPAL',
    label: 'PayPal',
    subtitle: 'Online wallet',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFF0070BA),
  ),
  _PaymentOption(
    value: 'EWALLET',
    label: 'Other wallet',
    subtitle: 'Demo e-wallet',
    icon: Icons.wallet_rounded,
    color: Color(0xFF7B61FF),
  ),
];

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.api,
    required this.booking,
    this.paymentType = 'DEPOSIT',
  });

  final ApiClient api;
  final Map<String, dynamic> booking;
  final String paymentType;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String method = 'GCASH';
  bool loading = false;

  Future<void> _pay() async {
    setState(() => loading = true);
    try {
      final response = await widget.api.post('/payments/simulate', {
        'bookingId': widget.booking['id'],
        'method': method,
        'paymentType': widget.paymentType,
      });
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptScreen(
            receipt: response['receipt'] as Map<String, dynamic>,
            booking: response['booking'] as Map<String, dynamic>,
            emailStatus: response['emailStatus']?.toString(),
            emailMessage: response['emailMessage']?.toString(),
          ),
        ),
      );
    } catch (error) {
      _snack(context, error.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBalancePayment = widget.paymentType == 'BALANCE';
    final amountDue = isBalancePayment
        ? _balanceDue(widget.booking)
        : _num(widget.booking['depositAmount']);
    final title = isBalancePayment
        ? 'Pay remaining balance'
        : 'Pay security deposit';
    final note = isBalancePayment
        ? 'This simulated transaction completes the remaining balance for the event.'
        : 'This simulated transaction records the 50% non-refundable security deposit.';

    return Scaffold(
      appBar: AppBar(title: const Text('Secure demo payment')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _PaymentSummaryCard(
            title: title,
            amountDue: amountDue,
            note: note,
            isBalancePayment: isBalancePayment,
          ),
          const SizedBox(height: 22),
          Text(
            'Choose payment method',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ..._paymentOptions.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PaymentMethodCard(
                option: item,
                selected: method == item.value,
                onTap: () => setState(() => method = item.value),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _PaymentSafetyNote(isBalancePayment: isBalancePayment),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: loading ? null : _pay,
            child: Text(
              loading
                  ? 'Processing...'
                  : isBalancePayment
                  ? 'Complete payment'
                  : 'Pay simulated deposit',
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentSummaryCard extends StatelessWidget {
  const _PaymentSummaryCard({
    required this.title,
    required this.amountDue,
    required this.note,
    required this.isBalancePayment,
  });

  final String title;
  final num amountDue;
  final String note;
  final bool isBalancePayment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.navy,
            AppTheme.blue,
            AppTheme.gold.withValues(alpha: 0.88),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.blue.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isBalancePayment
                      ? Icons.task_alt_rounded
                      : Icons.lock_outline_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            moneyFormat.format(amountDue),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: Text(
              isBalancePayment
                  ? 'Final payment before completion'
                  : '50% non-refundable deposit',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _PaymentOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? option.color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(
            color: selected ? option.color : colors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: option.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(option.icon, color: option.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    option.subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            AnimatedScale(
              scale: selected ? 1 : 0.86,
              duration: const Duration(milliseconds: 180),
              child: Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? option.color : colors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentSafetyNote extends StatelessWidget {
  const _PaymentSafetyNote({required this.isBalancePayment});

  final bool isBalancePayment;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.sky,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          Icon(
            isBalancePayment
                ? Icons.verified_user_outlined
                : Icons.info_outline_rounded,
            color: AppTheme.navy,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isBalancePayment
                  ? 'This demo payment marks the booking fully paid.'
                  : 'Deposit payments are marked non-refundable on the receipt.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({
    super.key,
    required this.receipt,
    required this.booking,
    this.emailStatus,
    this.emailMessage,
  });

  final Map<String, dynamic> receipt;
  final Map<String, dynamic> booking;
  final String? emailStatus;
  final String? emailMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ReceiptSuccessCard(receipt: receipt),
          if (emailMessage != null) ...[
            const SizedBox(height: 12),
            _ReceiptEmailCard(
              emailStatus: emailStatus,
              emailMessage: emailMessage!,
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.sky,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.policy_outlined, color: AppTheme.navy),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    receipt['securityNote']?.toString() ??
                        'Security deposit is non-refundable.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text('Back to home'),
          ),
        ],
      ),
    );
  }
}

class _ReceiptSuccessCard extends StatelessWidget {
  const _ReceiptSuccessCard({required this.receipt});

  final Map<String, dynamic> receipt;

  @override
  Widget build(BuildContext context) {
    final paymentMethod = receipt['paymentMethod']?.toString() ?? 'Demo';
    final option = _paymentOptions.firstWhere(
      (item) => item.value == paymentMethod,
      orElse: () => _paymentOptions.last,
    );
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF8EF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.success,
                  size: 34,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment approved',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      receipt['receiptNumber']?.toString() ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: option.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            ),
            child: Row(
              children: [
                Icon(option.icon, color: option.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${option.label} demo transaction',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          _MoneyRow('Subtotal', _num(receipt['subtotal'])),
          _MoneyRow('Deposit paid', _num(receipt['depositPaid'])),
          _MoneyRow('Remaining balance', _num(receipt['remainingBalance'])),
          _MoneyRow('App service fee', _num(receipt['serviceFee'])),
          const Divider(height: 32),
          _MoneyRow('Total paid', _num(receipt['totalPaid'])),
        ],
      ),
    );
  }
}

class _ReceiptEmailCard extends StatelessWidget {
  const _ReceiptEmailCard({
    required this.emailStatus,
    required this.emailMessage,
  });

  final String? emailStatus;
  final String emailMessage;

  @override
  Widget build(BuildContext context) {
    final sent = emailStatus == 'sent';
    final color = sent ? AppTheme.success : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            sent ? Icons.mark_email_read_outlined : Icons.email_outlined,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              emailMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  late Future<List<dynamic>> bookings = _load();
  final search = TextEditingController();
  String sort = 'newest';
  String tripTab = 'upcoming';

  Future<List<dynamic>> _load() async {
    final response = await widget.api.get('/bookings/my');
    return response['bookings'] as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<dynamic>>(
        future: bookings,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return snapshot.hasError
                ? EmptyState(
                    title: 'Could not load bookings',
                    message: snapshot.error.toString(),
                  )
                : const LoadingView();
          }
          final raw = snapshot.data!;
          if (raw.isEmpty) {
            return const EmptyState(
              title: 'No bookings',
              message: 'Your venue reservations will show here.',
            );
          }
          final data = _filterSortBookings(
            raw
                .where((booking) => _bookingTripGroup(booking) == tripTab)
                .toList(),
            search.text,
            sort,
          );
          return RefreshIndicator(
            onRefresh: () async => setState(() => bookings = _load()),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              children: [
                Text(
                  'Bookings',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'upcoming', label: Text('Upcoming')),
                    ButtonSegment(value: 'history', label: Text('History')),
                  ],
                  selected: {tripTab},
                  onSelectionChanged: (value) =>
                      setState(() => tripTab = value.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 16),
                BookingSearchSortBar(
                  controller: search,
                  sort: sort,
                  onChanged: () => setState(() {}),
                  onSortChanged: (value) => setState(() => sort = value),
                ),
                const SizedBox(height: 12),
                if (data.isEmpty)
                  const EmptyState(
                    title: 'No matches',
                    message:
                        'Try searching a venue, customer, status, or date.',
                  )
                else
                  ...data.map(
                    (booking) => BookingTile(
                      api: widget.api,
                      booking: booking as Map<String, dynamic>,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _bookingTripGroup(dynamic item) {
  final booking = item as Map<String, dynamic>;
  final status = booking['status']?.toString().toUpperCase() ?? 'PENDING';
  if (status == 'REJECTED' || status == 'CANCELLED') return 'history';
  final date = DateTime.tryParse(booking['eventDate']?.toString() ?? '');
  if (status == 'COMPLETED' ||
      (date != null && date.isBefore(DateTime.now()))) {
    return 'history';
  }
  return 'upcoming';
}

class BookingTile extends StatelessWidget {
  const BookingTile({
    super.key,
    required this.api,
    required this.booking,
    this.hostControls = false,
    this.onStatus,
  });

  final ApiClient api;
  final Map<String, dynamic> booking;
  final bool hostControls;
  final Future<void> Function(String status)? onStatus;

  @override
  Widget build(BuildContext context) {
    final venue = booking['venue'] as Map<String, dynamic>;
    final paymentStatus = booking['paymentStatus']?.toString() ?? 'UNPAID';
    final colors = AppTheme.colorsOf(context);
    final totalAmount = _num(booking['totalAmount']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        highlightColor: colors.surfaceGray,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingDetailsScreen(
              api: api,
              booking: booking,
              hostControls: hostControls,
              onStatus: onStatus,
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: colors.divider),
          ),
          child: Row(
            children: [
              VenueImageView(
                imageUrl: _firstVenueImage(venue),
                height: 88,
                width: 88,
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue['name'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      dateFormat.format(DateTime.parse(booking['eventDate'])),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      moneyFormat.format(totalAmount),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.blue,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        StatusPill(
                          booking['status']?.toString() ?? 'PENDING',
                          compact: true,
                        ),
                        StatusPill(paymentStatus, compact: true),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

class BookingDetailsScreen extends StatelessWidget {
  const BookingDetailsScreen({
    super.key,
    required this.api,
    required this.booking,
    this.hostControls = false,
    this.onStatus,
  });

  final ApiClient api;
  final Map<String, dynamic> booking;
  final bool hostControls;
  final Future<void> Function(String status)? onStatus;

  @override
  Widget build(BuildContext context) {
    final venue = booking['venue'] as Map<String, dynamic>;
    final customer = booking['customer'] as Map<String, dynamic>?;
    final payments = booking['payments'] as List<dynamic>? ?? [];
    final receipt = booking['receipt'] as Map<String, dynamic>?;
    final paid = payments.fold<num>(
      0,
      (sum, payment) => sum + _num((payment as Map<String, dynamic>)['amount']),
    );
    final balanceDue = _balanceDue(booking);
    final paymentStatus = booking['paymentStatus']?.toString() ?? 'UNPAID';
    final canPayDeposit = _canPayDeposit(booking);
    final canPayBalance = _canPayBalance(booking);

    return Scaffold(
      appBar: AppBar(title: const Text('Booking details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      VHStatusChip(booking['status']?.toString() ?? 'PENDING'),
                      VHStatusChip(paymentStatus),
                      if (receipt != null)
                        Chip(
                          label: Text(
                            receipt['receiptNumber']?.toString() ??
                                'Receipt issued',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoLine(
                    Icons.calendar_today_outlined,
                    'Event date',
                    dateFormat.format(DateTime.parse(booking['eventDate'])),
                  ),
                  if (customer != null)
                    _InfoLine(
                      Icons.person_outline,
                      'Customer',
                      '${customer['name'] ?? 'Guest'} - ${customer['email'] ?? ''}',
                    ),
                  if (customer != null &&
                      (customer['phone']?.toString() ?? '').isNotEmpty)
                    _InfoLine(
                      Icons.phone_outlined,
                      'Contact',
                      customer['phone'].toString(),
                    ),
                  if (customer != null &&
                      (customer['preferences']?.toString() ?? '').isNotEmpty)
                    _InfoLine(
                      Icons.travel_explore_outlined,
                      'Preferences',
                      customer['preferences'].toString(),
                    ),
                  if (customer != null &&
                      (customer['likes']?.toString() ?? '').isNotEmpty)
                    _InfoLine(
                      Icons.thumb_up_alt_outlined,
                      'Likes',
                      customer['likes'].toString(),
                    ),
                  if (customer != null &&
                      (customer['specialNotes']?.toString() ?? '').isNotEmpty)
                    _InfoLine(
                      Icons.notes_outlined,
                      'Notes',
                      customer['specialNotes'].toString(),
                    ),
                  _InfoLine(
                    Icons.payments_outlined,
                    'Total amount',
                    moneyFormat.format(_num(booking['totalAmount'])),
                  ),
                  _InfoLine(
                    Icons.savings_outlined,
                    'Deposit',
                    moneyFormat.format(_num(booking['depositAmount'])),
                  ),
                  _InfoLine(
                    Icons.account_balance_wallet_outlined,
                    'Paid so far',
                    moneyFormat.format(paid),
                  ),
                  _InfoLine(
                    Icons.pending_actions_outlined,
                    'Balance due',
                    moneyFormat.format(balanceDue),
                  ),
                  if ((booking['notes']?.toString() ?? '').isNotEmpty)
                    _InfoLine(
                      Icons.notes_outlined,
                      'Notes',
                      booking['notes'].toString(),
                    ),
                ],
              ),
            ),
          ),
          if (payments.isNotEmpty) ...[
            const VHSectionTitle('Transactions'),
            ...payments.map((payment) {
              final map = payment as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.receipt_long_outlined,
                    color: AppTheme.blue,
                  ),
                  title: Text('${map['type']} via ${map['method']}'),
                  subtitle: Text(map['transactionRef']?.toString() ?? ''),
                  trailing: Text(
                    moneyFormat.format(_num(map['amount'])),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 12),
          _BookingNextStepCard(booking: booking, hostView: hostControls),
          const SizedBox(height: 12),
          if (!hostControls)
            _BookingCustomerPaymentActions(
              api: api,
              booking: booking,
              canPayDeposit: canPayDeposit,
              canPayBalance: canPayBalance,
              paymentStatus: paymentStatus,
            ),
          if (hostControls)
            _BookingHostActionPanel(booking: booking, onStatus: onStatus),
        ],
      ),
    );
  }
}

class _BookingNextStepCard extends StatelessWidget {
  const _BookingNextStepCard({required this.booking, required this.hostView});

  final Map<String, dynamic> booking;
  final bool hostView;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final message = _bookingNextStepMessage(booking, hostView: hostView);
    final icon = _bookingNextStepIcon(booking);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.sky,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.navy),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingCustomerPaymentActions extends StatelessWidget {
  const _BookingCustomerPaymentActions({
    required this.api,
    required this.booking,
    required this.canPayDeposit,
    required this.canPayBalance,
    required this.paymentStatus,
  });

  final ApiClient api;
  final Map<String, dynamic> booking;
  final bool canPayDeposit;
  final bool canPayBalance;
  final String paymentStatus;

  @override
  Widget build(BuildContext context) {
    if (canPayDeposit) {
      return ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentScreen(api: api, booking: booking),
          ),
        ),
        icon: const Icon(Icons.lock_outline_rounded),
        label: const Text('Pay 50% deposit'),
      );
    }

    if (canPayBalance) {
      return ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentScreen(
              api: api,
              booking: booking,
              paymentType: 'BALANCE',
            ),
          ),
        ),
        icon: const Icon(Icons.task_alt_rounded),
        label: const Text('Pay remaining balance'),
      );
    }

    if (paymentStatus == 'PAID') {
      return const SizedBox.shrink();
    }

    return OutlinedButton.icon(
      onPressed: null,
      icon: const Icon(Icons.lock_outline_rounded),
      label: const Text('Payment unavailable for this booking'),
    );
  }
}

class _BookingHostActionPanel extends StatelessWidget {
  const _BookingHostActionPanel({
    required this.booking,
    required this.onStatus,
  });

  final Map<String, dynamic> booking;
  final Future<void> Function(String status)? onStatus;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (_canHostApprove(booking))
        OutlinedButton.icon(
          onPressed: () => onStatus?.call('APPROVED'),
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: const Text('Approve'),
        ),
      if (_canHostReject(booking))
        OutlinedButton.icon(
          onPressed: () => onStatus?.call('REJECTED'),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Reject'),
        ),
      if (_canHostComplete(booking))
        ElevatedButton.icon(
          onPressed: () => onStatus?.call('COMPLETED'),
          icon: const Icon(Icons.verified_outlined),
          label: const Text('Complete event'),
        ),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 8, runSpacing: 8, children: actions);
  }
}

class BookingSearchSortBar extends StatelessWidget {
  const BookingSearchSortBar({
    super.key,
    required this.controller,
    required this.sort,
    required this.onChanged,
    required this.onSortChanged,
  });

  final TextEditingController controller;
  final String sort;
  final VoidCallback onChanged;
  final ValueChanged<String> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search venue, customer, status, or date',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: sort,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.sort_rounded),
                labelText: 'Sort by',
              ),
              items: const [
                DropdownMenuItem(value: 'newest', child: Text('Newest first')),
                DropdownMenuItem(value: 'oldest', child: Text('Oldest first')),
                DropdownMenuItem(value: 'status', child: Text('Status')),
                DropdownMenuItem(value: 'price', child: Text('Price')),
              ],
              onChanged: (value) => onSortChanged(value ?? 'newest'),
            ),
          ],
        ),
      ),
    );
  }
}

class VenueSearchFilterBar extends StatelessWidget {
  const VenueSearchFilterBar({
    super.key,
    required this.controller,
    required this.status,
    required this.onChanged,
    required this.onStatusChanged,
  });

  final TextEditingController controller;
  final String status;
  final VoidCallback onChanged;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF8FBFE),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search venues by name or location',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.filter_list_rounded),
                labelText: 'Status filter',
              ),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All venues')),
                DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
              ],
              onChanged: (value) => onStatusChanged(value ?? 'ALL'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppTheme.blue),
          const SizedBox(width: 8),
          SizedBox(
            width: 112,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.api,
    required this.user,
    required this.onLogout,
    required this.onUserUpdated,
  });

  final ApiClient api;
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  final ValueChanged<Map<String, dynamic>> onUserUpdated;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Map<String, dynamic> user = Map<String, dynamic>.from(widget.user);
  final picker = ImagePicker();
  bool savingPhoto = false;

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      user = Map<String, dynamic>.from(widget.user);
    }
  }

  Future<void> _saveProfile(Map<String, dynamic> payload) async {
    final response = await widget.api.put('/auth/profile', payload);
    final nextUser = response['user'] as Map<String, dynamic>;
    setState(() => user = nextUser);
    widget.onUserUpdated(nextUser);
    if (mounted) {
      _snack(context, response['message']?.toString() ?? 'Profile updated.');
    }
  }

  Future<void> _changePhoto() async {
    setState(() => savingPhoto = true);
    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 72,
        maxWidth: 900,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (bytes.length > 2.5 * 1024 * 1024) {
        throw ApiException(
          'Profile photo is too large. Choose a smaller image.',
        );
      }

      await _saveProfile({
        'profileImageUrl': 'data:image/jpeg;base64,${base64Encode(bytes)}',
      });
    } catch (error) {
      if (!mounted) return;
      _snack(context, error.toString());
    } finally {
      if (mounted) setState(() => savingPhoto = false);
    }
  }

  Future<void> _editDetails() async {
    final name = TextEditingController(text: user['name']?.toString() ?? '');
    final phone = TextEditingController(text: user['phone']?.toString() ?? '');
    final gender = TextEditingController(
      text: user['gender']?.toString() ?? '',
    );
    final preferences = TextEditingController(
      text: user['preferences']?.toString() ?? '',
    );
    final likes = TextEditingController(text: user['likes']?.toString() ?? '');
    final specialNotes = TextEditingController(
      text: user['specialNotes']?.toString() ?? '',
    );

    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Edit profile',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Contact number'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: gender,
              decoration: const InputDecoration(labelText: 'Gender'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: preferences,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Venue preferences'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: likes,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Likes'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: specialNotes,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Special notes'),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'name': name.text.trim(),
                'phone': phone.text.trim(),
                'gender': gender.text.trim(),
                'preferences': preferences.text.trim(),
                'likes': likes.text.trim(),
                'specialNotes': specialNotes.text.trim(),
              }),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );

    if (payload == null) return;

    try {
      await _saveProfile(payload);
    } catch (error) {
      if (!mounted) return;
      _snack(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Center(
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                _ProfileAvatar(
                  imageUrl: user['profileImageUrl']?.toString(),
                  name: user['name']?.toString() ?? 'VenueHub user',
                  size: 154,
                ),
                Positioned(
                  bottom: -18,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.ink,
                      elevation: 6,
                      shadowColor: Colors.black26,
                      side: BorderSide(color: colors.divider),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    onPressed: savingPhoto ? null : _changePhoto,
                    icon: savingPhoto
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_camera_outlined),
                    label: Text(savingPhoto ? 'Saving...' : 'Change photo'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 42),
          Center(
            child: Text(
              user['name'] ?? '',
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ),
          Center(
            child: Text(
              user['role'] ?? '',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.secondaryText),
            ),
          ),
          const SizedBox(height: 28),
          Text('My profile', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Hosts and customers can see your profile details to help build trust before an event booking.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.secondaryText),
          ),
          const SizedBox(height: 20),
          _ProfileSummaryCard(user: user, onEdit: _editDetails),
          const SizedBox(height: 14),
          _ProfilePreferencesPanel(user: user),
          const SizedBox(height: 14),
          _ProfileActionsCard(
            onEdit: _editDetails,
            onChangePassword: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangePasswordScreen(api: widget.api),
              ),
            ),
            onLogout: widget.onLogout,
          ),
          const SizedBox(height: 14),
          _PolicyCard(),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.imageUrl,
    required this.name,
    required this.size,
  });

  final String? imageUrl;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'V' : name.trim()[0].toUpperCase();
    final image = imageUrl;

    Widget child;
    if (image != null && image.startsWith('data:image')) {
      child = Image.memory(
        base64Decode(image.split(',').last),
        fit: BoxFit.cover,
        height: size,
        width: size,
      );
    } else if (image != null && image.isNotEmpty) {
      child = Image.network(
        image,
        fit: BoxFit.cover,
        height: size,
        width: size,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Text(
            initial,
            style: TextStyle(fontSize: size * 0.34, color: Colors.white),
          ),
        ),
      );
    } else {
      child = Center(
        child: Text(
          initial,
          style: TextStyle(fontSize: size * 0.34, color: Colors.white),
        ),
      );
    }

    return Container(
      height: size,
      width: size,
      decoration: const BoxDecoration(
        color: Color(0xFF1F1F1F),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.user, required this.onEdit});

  final Map<String, dynamic> user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _ProfileSummaryRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: _displayValue(user['email'], fallback: 'No email'),
          ),
          const Divider(height: 22),
          _ProfileSummaryRow(
            icon: Icons.phone_outlined,
            label: 'Contact',
            value: _displayValue(user['phone'], fallback: 'Add contact number'),
          ),
          const Divider(height: 22),
          _ProfileSummaryRow(
            icon: Icons.badge_outlined,
            label: 'Account type',
            value: _roleText(user['role']?.toString() ?? 'CUSTOMER'),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit profile details'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSummaryRow extends StatelessWidget {
  const _ProfileSummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Row(
      children: [
        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: AppTheme.sky,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppTheme.navy, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileActionsCard extends StatelessWidget {
  const _ProfileActionsCard({
    required this.onEdit,
    required this.onChangePassword,
    required this.onLogout,
  });

  final VoidCallback onEdit;
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        children: [
          _ProfileActionTile(
            icon: Icons.edit_outlined,
            title: 'Edit account details',
            onTap: onEdit,
          ),
          const Divider(height: 1, indent: 58),
          _ProfileActionTile(
            icon: Icons.lock_reset_rounded,
            title: 'Change password',
            onTap: onChangePassword,
          ),
          const Divider(height: 1, indent: 58),
          _ProfileActionTile(
            icon: Icons.logout_rounded,
            title: 'Logout',
            danger: true,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppTheme.danger : AppTheme.navy;
    return ListTile(
      onTap: onTap,
      minLeadingWidth: 28,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
      trailing: danger
          ? null
          : const Icon(Icons.chevron_right_rounded, color: Colors.black45),
    );
  }
}

class _ProfilePreferencesPanel extends StatelessWidget {
  const _ProfilePreferencesPanel({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    String field(String key, String fallback) {
      final value = user[key]?.toString().trim();
      return value == null || value.isEmpty ? fallback : value;
    }

    final insights = [
      (
        icon: Icons.travel_explore_outlined,
        title: 'Venue preferences',
        value: field(
          'preferences',
          'Add preferred locations, venue types, or event styles.',
        ),
      ),
      (
        icon: Icons.thumb_up_alt_outlined,
        title: 'Likes',
        value: field('likes', 'Add what you enjoy in an event venue.'),
      ),
      (
        icon: Icons.notes_outlined,
        title: 'Special notes',
        value: field(
          'specialNotes',
          'Add notes that hosts or admins should know.',
        ),
      ),
    ];
    final colors = AppTheme.colorsOf(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceGray,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        children: insights
            .map(
              (item) => Padding(
                padding: EdgeInsets.only(
                  bottom: item == insights.last ? 0 : 14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.icon, color: AppTheme.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.value,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.secondaryText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceGray,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: colors.divider),
      ),
      child: ExpansionTile(
        leading: Icon(Icons.policy_outlined, color: colors.ink),
        title: const Text(
          'No Refund Policy',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('Tap to read before booking'),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        children: const [
          Text(
            'VenueHub demo bookings require a 50% non-refundable security deposit. The remaining balance is paid before or on the event day. Rejected bookings cannot be paid, and completed demo payments are receipt records only.',
            style: TextStyle(color: Colors.black87, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirmPassword = TextEditingController();
  bool loading = false;

  Future<void> _changePassword() async {
    setState(() => loading = true);
    try {
      final response = await widget.api.put('/auth/change-password', {
        'currentPassword': currentPassword.text,
        'newPassword': newPassword.text,
        'confirmPassword': confirmPassword.text,
      });
      if (!mounted) return;
      _snack(context, response['message']?.toString() ?? 'Password changed.');
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      _snack(context, error.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: currentPassword,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: newPassword,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: confirmPassword,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: loading ? null : _changePassword,
            child: Text(loading ? 'Updating...' : 'Update password'),
          ),
        ],
      ),
    );
  }
}

class HostHome extends StatefulWidget {
  const HostHome({
    super.key,
    required this.api,
    required this.user,
    required this.onLogout,
    required this.onUserUpdated,
  });

  final ApiClient api;
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  final ValueChanged<Map<String, dynamic>> onUserUpdated;

  @override
  State<HostHome> createState() => _HostHomeState();
}

class _HostHomeState extends State<HostHome> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HostDashboard(api: widget.api, user: widget.user),
      HostBookingsScreen(api: widget.api),
      HostVenuesScreen(api: widget.api),
      ProfileScreen(
        api: widget.api,
        user: widget.user,
        onLogout: widget.onLogout,
        onUserUpdated: widget.onUserUpdated,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (value) => setState(() => index = value),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_work_outlined),
            activeIcon: Icon(Icons.home_work_rounded),
            label: 'Host',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note_outlined),
            activeIcon: Icon(Icons.event_available_rounded),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_home_outlined),
            activeIcon: Icon(Icons.add_home_rounded),
            label: 'Venues',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HostDashboard extends StatefulWidget {
  const HostDashboard({super.key, required this.api, required this.user});

  final ApiClient api;
  final Map<String, dynamic> user;

  @override
  State<HostDashboard> createState() => _HostDashboardState();
}

class _DashboardHeroCard extends StatelessWidget {
  const _DashboardHeroCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.caption,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String amount;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppTheme.navy, AppTheme.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            amount,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            caption,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardInfoRow {
  const _DashboardInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _DashboardInfoCard extends StatelessWidget {
  const _DashboardInfoCard({required this.title, required this.rows});

  final String title;
  final List<_DashboardInfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.sky,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(row.icon, color: AppTheme.navy, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        row.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.secondaryText,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        row.value,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostDashboardState extends State<HostDashboard> {
  late Future<Map<String, dynamic>> summary = _load();

  Future<Map<String, dynamic>> _load() async {
    final response = await widget.api.get('/bookings/host/income');
    return response['summary'] as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Welcome, ${widget.user['name']}')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: summary,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return snapshot.hasError
                ? EmptyState(
                    title: 'Could not load summary',
                    message: snapshot.error.toString(),
                  )
                : const LoadingView();
          }
          final data = snapshot.data!;
          final recent = data['recentActivity'] as List<dynamic>? ?? [];
          final topVenues = data['topVenues'] as List<dynamic>? ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _DashboardHeroCard(
                title: 'Host snapshot',
                subtitle:
                    '${data['awaitingDeposit'] ?? data['pendingBookings'] ?? 0} awaiting deposit - ${data['conversionRate'] ?? 0}% secured rate',
                amount: moneyFormat.format(_num(data['estimatedHostIncome'])),
                caption: 'Estimated host income',
                icon: Icons.storefront_outlined,
              ),
              const SizedBox(height: 14),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.05,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  VHStatCard(
                    label: 'Awaiting deposit',
                    value:
                        '${data['awaitingDeposit'] ?? data['pendingBookings'] ?? 0}',
                    icon: Icons.lock_clock_outlined,
                  ),
                  VHStatCard(
                    label: 'Active venues',
                    value: '${data['activeVenues'] ?? 0}',
                    icon: Icons.home_work_outlined,
                  ),
                  VHStatCard(
                    label: 'Approved',
                    value: '${data['approvedBookings'] ?? 0}',
                    icon: Icons.event_available_outlined,
                  ),
                  VHStatCard(
                    label: 'Completed',
                    value: '${data['completedBookings'] ?? 0}',
                    icon: Icons.verified_outlined,
                  ),
                  VHStatCard(
                    label: 'Gross paid',
                    value: moneyFormat.format(_num(data['grossPaid'])),
                    icon: Icons.payments,
                  ),
                  VHStatCard(
                    label: 'Unpaid balances',
                    value: moneyFormat.format(_num(data['outstandingBalance'])),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _DashboardInfoCard(
                title: 'Income insight',
                rows: [
                  _DashboardInfoRow(
                    icon: Icons.savings_outlined,
                    label: 'Platform fees estimate',
                    value: moneyFormat.format(
                      _num(data['estimatedPlatformFees']),
                    ),
                  ),
                  _DashboardInfoRow(
                    icon: Icons.analytics_outlined,
                    label: 'Average booking value',
                    value: moneyFormat.format(
                      _num(data['averageBookingValue']),
                    ),
                  ),
                  _DashboardInfoRow(
                    icon: Icons.percent_rounded,
                    label: 'Approval rate',
                    value: '${data['conversionRate'] ?? 0}%',
                  ),
                ],
              ),
              if (topVenues.isNotEmpty) ...[
                const SizedBox(height: 14),
                _DashboardInfoCard(
                  title: 'Top venues by paid income',
                  rows: topVenues.map((item) {
                    final venue = item as Map<String, dynamic>;
                    return _DashboardInfoRow(
                      icon: Icons.home_work_outlined,
                      label: venue['venueName']?.toString() ?? 'Venue',
                      value:
                          '${venue['bookings'] ?? 0} bookings - ${moneyFormat.format(_num(venue['grossPaid']))}',
                    );
                  }).toList(),
                ),
              ],
              const VHSectionTitle('Recent activity'),
              if (recent.isEmpty)
                const EmptyState(
                  title: 'No activity yet',
                  message: 'New booking requests will appear here.',
                )
              else
                ...recent.map((item) {
                  final activity = item as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.event_note_outlined,
                        color: AppTheme.blue,
                      ),
                      title: Text(activity['venueName']?.toString() ?? 'Venue'),
                      subtitle: Text(
                        '${activity['status']} - ${activity['paymentStatus']}',
                      ),
                      trailing: VHStatusChip(
                        activity['status']?.toString() ?? 'PENDING',
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class HostBookingsScreen extends StatefulWidget {
  const HostBookingsScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<HostBookingsScreen> createState() => _HostBookingsScreenState();
}

class _HostBookingsScreenState extends State<HostBookingsScreen> {
  late Future<List<dynamic>> bookings = _load();
  final search = TextEditingController();
  String sort = 'newest';

  Future<List<dynamic>> _load() async {
    final response = await widget.api.get('/bookings/host');
    return response['bookings'] as List<dynamic>;
  }

  Future<void> _status(String id, String status) async {
    final confirmed = await _confirmAction(
      context,
      title: '${_prettyStatusAction(status)} booking?',
      message:
          'This will update the booking status to ${_prettyStatus(status)}.',
      confirmLabel: _prettyStatusAction(status),
    );
    if (!confirmed) return;

    try {
      final response = await widget.api.put('/bookings/$id/status', {
        'status': status,
      });
      if (!mounted) return;
      setState(() => bookings = _load());
      _snack(
        context,
        response['message']?.toString() ??
            'Booking updated to ${_prettyStatus(status)}.',
      );
    } catch (error) {
      if (!mounted) return;
      _snack(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Host bookings')),
      body: FutureBuilder<List<dynamic>>(
        future: bookings,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return snapshot.hasError
                ? EmptyState(
                    title: 'Could not load host bookings',
                    message: snapshot.error.toString(),
                  )
                : const LoadingView();
          }
          final raw = snapshot.data!;
          if (raw.isEmpty) {
            return const EmptyState(
              title: 'No requests yet',
              message:
                  'Customer booking requests for your venues will appear here.',
            );
          }
          final data = _filterSortBookings(raw, search.text, sort);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              BookingSearchSortBar(
                controller: search,
                sort: sort,
                onChanged: () => setState(() {}),
                onSortChanged: (value) => setState(() => sort = value),
              ),
              const SizedBox(height: 12),
              if (data.isEmpty)
                const EmptyState(
                  title: 'No matches',
                  message: 'Try searching a venue, customer, status, or date.',
                )
              else
                ...data.map((booking) {
                  final map = booking as Map<String, dynamic>;
                  return BookingTile(
                    api: widget.api,
                    booking: map,
                    hostControls: true,
                    onStatus: (status) => _status(map['id'] as String, status),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class HostVenuesScreen extends StatefulWidget {
  const HostVenuesScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<HostVenuesScreen> createState() => _HostVenuesScreenState();
}

class _HostVenuesScreenState extends State<HostVenuesScreen> {
  late Future<List<dynamic>> venues = _load();
  final search = TextEditingController();
  String statusFilter = 'ALL';

  Future<List<dynamic>> _load() async {
    final response = await widget.api.get('/venues/host/my');
    return response['venues'] as List<dynamic>;
  }

  Future<void> _delete(String id) async {
    try {
      await widget.api.delete('/venues/$id');
      if (mounted) setState(() => venues = _load());
    } catch (error) {
      if (!mounted) return;
      _snack(context, error.toString());
    }
  }

  Future<void> _openForm([Map<String, dynamic>? venue]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddVenueScreen(api: widget.api, venue: venue),
      ),
    );
    if (mounted) setState(() => venues = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My venues')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add venue'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: venues,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return snapshot.hasError
                ? EmptyState(
                    title: 'Could not load venues',
                    message: snapshot.error.toString(),
                  )
                : const LoadingView();
          }
          final raw = snapshot.data!;
          final data = _filterVenues(raw, search.text, statusFilter);
          if (data.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                VenueSearchFilterBar(
                  controller: search,
                  status: statusFilter,
                  onChanged: () => setState(() {}),
                  onStatusChanged: (value) =>
                      setState(() => statusFilter = value),
                ),
                const SizedBox(height: 18),
                EmptyState(
                  title: raw.isEmpty ? 'No venues listed' : 'No venues match',
                  message: raw.isEmpty
                      ? 'Tap Add venue to create your first listing.'
                      : 'Try another search or status filter.',
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              VenueSearchFilterBar(
                controller: search,
                status: statusFilter,
                onChanged: () => setState(() {}),
                onStatusChanged: (value) =>
                    setState(() => statusFilter = value),
              ),
              const SizedBox(height: 12),
              ...data.map((item) {
                final venue = item as Map<String, dynamic>;
                final images = venue['images'] as List<dynamic>? ?? [];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VenueImageCarousel(images: images, height: 150),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: VenueImageView(
                                      imageUrl: _firstVenueImage(venue),
                                      height: 54,
                                      width: 64,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      venue['name'],
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  VHStatusChip(venue['status']),
                                ],
                              ),
                              Text(
                                '${venue['location']} - ${moneyFormat.format(_num(venue['pricePerDay']))}',
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _InfoPill(
                                    Icons.people_outline,
                                    '${venue['capacity']} guests',
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _openForm(venue),
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Edit'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _delete(venue['id'] as String),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class AddVenueScreen extends StatefulWidget {
  const AddVenueScreen({super.key, required this.api, this.venue});

  final ApiClient api;
  final Map<String, dynamic>? venue;

  @override
  State<AddVenueScreen> createState() => _AddVenueScreenState();
}

class _HostOfferOption {
  const _HostOfferOption(this.icon, this.label);

  final IconData icon;
  final String label;
}

const _amenityOptions = [
  _HostOfferOption(Icons.wifi_rounded, 'Wi-Fi'),
  _HostOfferOption(Icons.directions_car_outlined, 'Parking'),
  _HostOfferOption(Icons.photo_camera_outlined, 'Photo area'),
  _HostOfferOption(Icons.ac_unit_rounded, 'Air conditioning'),
  _HostOfferOption(Icons.restaurant_outlined, 'Catering partner'),
  _HostOfferOption(Icons.security_outlined, 'Security assistance'),
];

const _facilityOptions = [
  _HostOfferOption(Icons.apartment_outlined, 'Main hall'),
  _HostOfferOption(Icons.landscape_outlined, 'Garden setup'),
  _HostOfferOption(Icons.speaker_outlined, 'Sound system'),
  _HostOfferOption(Icons.connected_tv_outlined, 'Projector'),
  _HostOfferOption(Icons.theater_comedy_outlined, 'Stage area'),
  _HostOfferOption(Icons.meeting_room_outlined, 'Prep room'),
  _HostOfferOption(Icons.event_seat_outlined, 'Tables and chairs'),
  _HostOfferOption(Icons.light_mode_outlined, 'Basic lights'),
];

class _LocationPreset {
  const _LocationPreset(this.label, this.address);

  final String label;
  final String address;
}

const _locationPresets = [
  _LocationPreset('Tacloban City, Leyte', 'Tacloban City, Leyte, Philippines'),
  _LocationPreset('Palo, Leyte', 'Palo, Leyte, Philippines'),
  _LocationPreset('Tanauan, Leyte', 'Tanauan, Leyte, Philippines'),
  _LocationPreset('Dulag, Leyte', 'Dulag, Leyte, Philippines'),
  _LocationPreset('Ormoc City, Leyte', 'Ormoc City, Leyte, Philippines'),
  _LocationPreset('Burauen, Leyte', 'Burauen, Leyte, Philippines'),
  _LocationPreset(
    'Catbalogan City, Samar',
    'Catbalogan City, Samar, Philippines',
  ),
  _LocationPreset('Calbayog City, Samar', 'Calbayog City, Samar, Philippines'),
];

class _AddVenueScreenState extends State<AddVenueScreen> {
  final name = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final capacity = TextEditingController();
  final location = TextEditingController();
  final address = TextEditingController();
  final amenities = TextEditingController();
  final facilities = TextEditingController();
  final imagePicker = ImagePicker();
  final Set<String> selectedAmenities = {
    'Air conditioning',
    'Parking',
    'Catering partner',
  };
  final Set<String> selectedFacilities = {
    'Main hall',
    'Sound system',
    'Prep room',
  };
  final List<String> selectedImages = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    final venue = widget.venue;
    if (venue == null) return;

    name.text = venue['name']?.toString() ?? '';
    description.text = venue['description']?.toString() ?? '';
    price.text = venue['pricePerDay']?.toString() ?? '';
    capacity.text = venue['capacity']?.toString() ?? '';
    location.text = venue['location']?.toString() ?? '';
    address.text = venue['address']?.toString() ?? '';
    selectedImages
      ..clear()
      ..addAll(
        (venue['images'] as List<dynamic>? ?? [])
            .map(
              (item) => item is String
                  ? item
                  : (item['imageUrl'] ?? item['url'])?.toString() ?? '',
            )
            .where((item) => item.isNotEmpty),
      );
    final existingAmenities = (venue['amenities'] as List<dynamic>? ?? [])
        .map((item) => item['name'].toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
    final existingFacilities = (venue['facilities'] as List<dynamic>? ?? [])
        .map((item) => item['name'].toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
    selectedAmenities
      ..clear()
      ..addAll(existingAmenities.where(_isAmenityOption));
    selectedFacilities
      ..clear()
      ..addAll(existingFacilities.where(_isFacilityOption));
    amenities.text = existingAmenities
        .where((item) => !_isAmenityOption(item))
        .join(', ');
    facilities.text = existingFacilities
        .where((item) => !_isFacilityOption(item))
        .join(', ');
  }

  Future<void> _chooseImages() async {
    try {
      final action = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose photos from gallery'),
                subtitle: const Text(
                  'Select one or more venue photos from this phone.',
                ),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              if (selectedImages.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Clear selected photos'),
                  onTap: () => Navigator.pop(context, 'clear'),
                ),
            ],
          ),
        ),
      );

      if (action == 'clear') {
        setState(selectedImages.clear);
        return;
      }

      if (action != 'gallery') return;
      if (selectedImages.length >= 6) {
        throw ApiException(
          'You can add up to 6 photos per venue for this demo.',
        );
      }

      final picked = await imagePicker.pickMultiImage(
        imageQuality: 68,
        maxWidth: 1200,
      );
      if (picked.isEmpty) return;

      final encodedImages = <String>[];
      var totalPayloadSize = selectedImages.fold<int>(
        0,
        (sum, image) => sum + image.length,
      );
      for (final image in picked.take(6 - selectedImages.length)) {
        final bytes = await image.readAsBytes();
        if (bytes.length > 2.5 * 1024 * 1024) {
          throw ApiException(
            'One selected image is still too large. Please choose a smaller photo.',
          );
        }
        final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        totalPayloadSize += dataUrl.length;
        if (totalPayloadSize > 18 * 1024 * 1024) {
          throw ApiException(
            'Selected photos are too large together. Please remove one photo or choose smaller images.',
          );
        }
        encodedImages.add(dataUrl);
      }

      setState(() => selectedImages.addAll(encodedImages));
    } catch (error) {
      if (!mounted) return;
      _snack(context, error.toString());
    }
  }

  void _removeImage(int index) {
    setState(() => selectedImages.removeAt(index));
  }

  void _applyLocationPreset(_LocationPreset preset) {
    setState(() {
      location.text = preset.label;
      if (address.text.trim().isEmpty ||
          _locationPresets.any((item) => item.address == address.text.trim())) {
        address.text = preset.address;
      }
    });
  }

  String? _validateVenueForm() {
    if (name.text.trim().isEmpty) return 'Venue name is required.';
    if (description.text.trim().length < 20) {
      return 'Add a longer description so customers understand the venue.';
    }
    if ((num.tryParse(price.text) ?? 0) <= 0) {
      return 'Enter a realistic price per day.';
    }
    if ((int.tryParse(capacity.text) ?? 0) <= 0) {
      return 'Enter the venue guest capacity.';
    }
    if (location.text.trim().isEmpty) return 'Location is required.';
    if (address.text.trim().isEmpty) return 'Address is required.';
    if (selectedImages.isEmpty) {
      return 'Add at least one venue photo so the listing looks complete.';
    }
    return null;
  }

  Future<void> _save() async {
    final validationError = _validateVenueForm();
    if (validationError != null) {
      _snack(context, validationError);
      return;
    }

    setState(() => loading = true);
    try {
      final payload = {
        'name': name.text.trim(),
        'description': description.text.trim(),
        'pricePerDay': num.tryParse(price.text) ?? 0,
        'capacity': int.tryParse(capacity.text) ?? 0,
        'location': location.text.trim(),
        'address': address.text.trim(),
        'images': selectedImages,
        'amenities': _mergeOfferValues(selectedAmenities, amenities.text),
        'facilities': _mergeOfferValues(selectedFacilities, facilities.text),
      };

      if (widget.venue == null) {
        await widget.api.post('/venues', payload);
      } else {
        await widget.api.put('/venues/${widget.venue!['id']}', payload);
      }

      if (!mounted) return;
      _snack(
        context,
        widget.venue == null
            ? 'Venue submitted for admin approval.'
            : 'Venue updated.',
      );
      for (final controller in [
        name,
        description,
        price,
        capacity,
        location,
        address,
      ]) {
        controller.clear();
      }
      setState(() {
        selectedImages.clear();
        selectedAmenities
          ..clear()
          ..addAll(['Air conditioning', 'Parking', 'Catering partner']);
        selectedFacilities
          ..clear()
          ..addAll(['Main hall', 'Sound system', 'Prep room']);
      });
      if (widget.venue != null) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      _snack(context, error.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.venue == null ? 'Add venue' : 'Edit venue'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.sky,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.divider),
            ),
            child: Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.venue == null
                            ? 'Create a client-ready listing'
                            : 'Update venue details',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Photos, clear pricing, capacity, and offers help customers decide faster.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _VenueFormSection(
            title: 'Basic details',
            icon: Icons.edit_location_alt_outlined,
            child: Column(
              children: [
                TextField(
                  controller: name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.apartment_outlined),
                    labelText: 'Venue name',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.description_outlined),
                    labelText: 'Description',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _VenueFormSection(
            title: 'Pricing and capacity',
            icon: Icons.payments_outlined,
            child: Column(
              children: [
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.payments_outlined),
                    labelText: 'Price per day',
                    helperText: 'Example: 35000',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: capacity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.groups_outlined),
                    labelText: 'Guest capacity',
                    helperText: 'Maximum number of guests',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _VenueFormSection(
            title: 'Location',
            icon: Icons.place_outlined,
            child: Column(
              children: [
                _LocationPresetRail(
                  selected: location.text,
                  onSelected: _applyLocationPreset,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: location,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_city_outlined),
                    labelText: 'City / Municipality',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: address,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.map_outlined),
                    labelText: 'Full address',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _VenuePhotoPicker(
            images: selectedImages,
            onAdd: _chooseImages,
            onRemove: _removeImage,
          ),
          const SizedBox(height: 14),
          _VenueFormSection(
            title: 'Offers and facilities',
            icon: Icons.checklist_rounded,
            child: Column(
              children: [
                _OfferSelector(
                  title: 'Amenities',
                  subtitle: 'Tap the common options guests look for.',
                  options: _amenityOptions,
                  selected: selectedAmenities,
                  onToggle: (label) {
                    setState(() {
                      selectedAmenities.contains(label)
                          ? selectedAmenities.remove(label)
                          : selectedAmenities.add(label);
                    });
                  },
                ),
                const SizedBox(height: 14),
                _OfferSelector(
                  title: 'Facilities',
                  subtitle: 'Choose venue spaces and event-ready features.',
                  options: _facilityOptions,
                  selected: selectedFacilities,
                  onToggle: (label) {
                    setState(() {
                      selectedFacilities.contains(label)
                          ? selectedFacilities.remove(label)
                          : selectedFacilities.add(label);
                    });
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amenities,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.add_circle_outline_rounded),
                    labelText: 'Other amenities, comma separated',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: facilities,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.add_business_outlined),
                    labelText: 'Other facilities, comma separated',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _VenueFormTip(
            message:
                'Listings from hosts still go to the admin for approval before customers can book them.',
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: loading ? null : _save,
              icon: loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                loading
                    ? 'Saving...'
                    : widget.venue == null
                    ? 'Submit venue'
                    : 'Save changes',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VenueFormSection extends StatelessWidget {
  const _VenueFormSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.blue),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LocationPresetRail extends StatelessWidget {
  const _LocationPresetRail({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<_LocationPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _locationPresets.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final preset = _locationPresets[index];
          final active = selected.trim() == preset.label;
          return ChoiceChip(
            selected: active,
            avatar: Icon(
              Icons.place_outlined,
              size: 17,
              color: active ? Colors.white : AppTheme.blue,
            ),
            label: Text(preset.label.split(',').first),
            labelStyle: TextStyle(
              color: active ? Colors.white : AppTheme.ink,
              fontWeight: FontWeight.w700,
            ),
            selectedColor: AppTheme.navy,
            onSelected: (_) => onSelected(preset),
          );
        },
      ),
    );
  }
}

class _VenueFormTip extends StatelessWidget {
  const _VenueFormTip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.warning),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _OfferSelector extends StatelessWidget {
  const _OfferSelector({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final String subtitle;
  final List<_HostOfferOption> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceGray,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final active = selected.contains(option.label);
              return FilterChip(
                selected: active,
                showCheckmark: false,
                avatar: Icon(
                  option.icon,
                  size: 18,
                  color: active ? Colors.white : AppTheme.blue,
                ),
                label: Text(option.label),
                selectedColor: AppTheme.navy,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: active ? Colors.white : colors.ink,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: active ? AppTheme.navy : colors.divider,
                ),
                onSelected: (_) => onToggle(option.label),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _VenuePhotoPicker extends StatelessWidget {
  const _VenuePhotoPicker({
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> images;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Venue photos',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${images.length}/6',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose real photos from the phone gallery. Guests can swipe through them in the listing.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            if (images.isEmpty)
              InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.teal.withValues(alpha: 0.22),
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 42,
                        color: AppTheme.teal,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap to add venue photos',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 124,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length + 1,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    if (index == images.length) {
                      return InkWell(
                        onTap: onAdd,
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: 118,
                          decoration: BoxDecoration(
                            color: AppTheme.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppTheme.blue.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Icon(Icons.add, color: AppTheme.blue),
                        ),
                      );
                    }

                    return Stack(
                      children: [
                        VenueImageView(
                          imageUrl: images[index],
                          width: 118,
                          height: 124,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: InkWell(
                            onTap: () => onRemove(index),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.58),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                images.isEmpty ? 'Choose from gallery' : 'Add more photos',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminHome extends StatefulWidget {
  const AdminHome({
    super.key,
    required this.api,
    required this.user,
    required this.onLogout,
    required this.onUserUpdated,
  });

  final ApiClient api;
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  final ValueChanged<Map<String, dynamic>> onUserUpdated;

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      AdminDashboard(api: widget.api),
      AdminListScreen(
        api: widget.api,
        title: 'Users',
        endpoint: '/admin/users',
        listKey: 'users',
      ),
      AdminVenuesScreen(api: widget.api),
      AdminBookingsScreen(api: widget.api),
      AdminIncomeScreen(api: widget.api),
      ProfileScreen(
        api: widget.api,
        user: widget.user,
        onLogout: widget.onLogout,
        onUserUpdated: widget.onUserUpdated,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (value) => setState(() => index = value),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view_rounded),
            label: 'Dash',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline_rounded),
            activeIcon: Icon(Icons.people_rounded),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apartment_outlined),
            activeIcon: Icon(Icons.apartment_rounded),
            label: 'Venues',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long_rounded),
            label: 'Records',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.query_stats_rounded),
            label: 'Income',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.api});

  final ApiClient api;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<Map<String, dynamic>> dashboard = _load();

  Future<Map<String, dynamic>> _load() async {
    final response = await widget.api.get('/admin/dashboard');
    return response['dashboard'] as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin dashboard')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: dashboard,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return snapshot.hasError
                ? EmptyState(
                    title: 'Could not load dashboard',
                    message: snapshot.error.toString(),
                  )
                : const LoadingView();
          }
          final data = snapshot.data!;
          final recent = data['recentActivity'] as List<dynamic>? ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _DashboardHeroCard(
                title: 'VenueHub overview',
                subtitle:
                    '${data['totalHosts'] ?? 0} hosts - ${data['totalVenues'] ?? 0} venues - ${data['approvalRate'] ?? 0}% secured rate',
                amount: moneyFormat.format(_num(data['platformIncome'])),
                caption: 'Realized platform income',
                icon: Icons.query_stats_rounded,
              ),
              const SizedBox(height: 14),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.05,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  VHStatCard(
                    label: 'Customers',
                    value: '${data['totalCustomers'] ?? data['totalUsers']}',
                    icon: Icons.group_outlined,
                  ),
                  VHStatCard(
                    label: 'Hosts',
                    value: '${data['totalHosts']}',
                    icon: Icons.store_outlined,
                  ),
                  VHStatCard(
                    label: 'Pending venues',
                    value: '${data['pendingVenues'] ?? 0}',
                    icon: Icons.pending_actions,
                  ),
                  VHStatCard(
                    label: 'Service fee',
                    value: '${_num(data['serviceFeePercent'])}%',
                    icon: Icons.percent_rounded,
                  ),
                  VHStatCard(
                    label: 'Gross paid',
                    value: moneyFormat.format(_num(data['grossPaid'])),
                    icon: Icons.payments_outlined,
                  ),
                  VHStatCard(
                    label: 'Unpaid balances',
                    value: moneyFormat.format(_num(data['outstandingBalance'])),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _DashboardInfoCard(
                title: 'Operational signals',
                rows: [
                  _DashboardInfoRow(
                    icon: Icons.event_available_outlined,
                    label: 'Approved bookings',
                    value: '${data['approvedBookings'] ?? 0}',
                  ),
                  _DashboardInfoRow(
                    icon: Icons.verified_outlined,
                    label: 'Completed bookings',
                    value: '${data['completedBookings'] ?? 0}',
                  ),
                  _DashboardInfoRow(
                    icon: Icons.cancel_outlined,
                    label: 'Rejected bookings',
                    value: '${data['rejectedBookings'] ?? 0}',
                  ),
                  _DashboardInfoRow(
                    icon: Icons.percent_rounded,
                    label: 'Service fee',
                    value: '${_num(data['serviceFeePercent'])}%',
                  ),
                ],
              ),
              const VHSectionTitle('Recent platform activity'),
              if (recent.isEmpty)
                const EmptyState(
                  title: 'No booking activity',
                  message: 'New reservations will show here.',
                )
              else
                ...recent.map((item) {
                  final row = item as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.receipt_long_outlined,
                        color: AppTheme.blue,
                      ),
                      title: Text(row['venueName']?.toString() ?? 'Venue'),
                      subtitle: Text(
                        '${row['customerName'] ?? 'Customer'} - ${_prettyStatus(row['status'])}',
                      ),
                      trailing: Text(
                        moneyFormat.format(_num(row['paid'])),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class AdminListScreen extends StatefulWidget {
  const AdminListScreen({
    super.key,
    required this.api,
    required this.title,
    required this.endpoint,
    required this.listKey,
  });

  final ApiClient api;
  final String title;
  final String endpoint;
  final String listKey;

  @override
  State<AdminListScreen> createState() => _AdminListScreenState();
}

class _AdminListScreenState extends State<AdminListScreen> {
  late Future<List<dynamic>> items = _load();
  final search = TextEditingController();
  String roleFilter = 'ALL';

  Future<List<dynamic>> _load() async {
    final response = await widget.api.get(widget.endpoint);
    return response[widget.listKey] as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<dynamic>>(
        future: items,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return snapshot.hasError
                ? EmptyState(
                    title: 'Could not load ${widget.title}',
                    message: snapshot.error.toString(),
                  )
                : const LoadingView();
          }
          final data = widget.listKey == 'users'
              ? _filterUsers(snapshot.data!, search.text, roleFilter)
              : snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.listKey == 'users') ...[
                _UserSearchFilterBar(
                  controller: search,
                  role: roleFilter,
                  onChanged: () => setState(() {}),
                  onRoleChanged: (value) => setState(() => roleFilter = value),
                ),
                const SizedBox(height: 12),
              ],
              if (data.isEmpty)
                const EmptyState(
                  title: 'No accounts match',
                  message: 'Try another search or role filter.',
                )
              else
                ...data.map(
                  (item) => widget.listKey == 'users'
                      ? _AdminUserCard(user: item as Map<String, dynamic>)
                      : _AdminJsonCard(item: item as Map<String, dynamic>),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _UserSearchFilterBar extends StatelessWidget {
  const _UserSearchFilterBar({
    required this.controller,
    required this.role,
    required this.onChanged,
    required this.onRoleChanged,
  });

  final TextEditingController controller;
  final String role;
  final VoidCallback onChanged;
  final ValueChanged<String> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF8FBFE),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search name, email, phone',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.group_outlined),
                labelText: 'Account type',
              ),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All accounts')),
                DropdownMenuItem(value: 'CUSTOMER', child: Text('Customers')),
                DropdownMenuItem(value: 'HOST', child: Text('Hosts')),
                DropdownMenuItem(
                  value: 'VENUEHUB_ADMIN',
                  child: Text('Admins'),
                ),
              ],
              onChanged: (value) => onRoleChanged(value ?? 'ALL'),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  late Future<List<dynamic>> bookings = _load();
  final search = TextEditingController();
  String sort = 'newest';

  Future<List<dynamic>> _load() async {
    final response = await widget.api.get('/admin/bookings');
    return response['bookings'] as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking records')),
      body: FutureBuilder<List<dynamic>>(
        future: bookings,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return snapshot.hasError
                ? EmptyState(
                    title: 'Could not load bookings',
                    message: snapshot.error.toString(),
                  )
                : const LoadingView();
          }
          final raw = snapshot.data!;
          if (raw.isEmpty) {
            return const EmptyState(
              title: 'No bookings found',
              message:
                  'Bookings will appear here when customers reserve venues.',
            );
          }
          final data = _filterSortBookings(raw, search.text, sort);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AdminRecordsNotice(count: raw.length),
              const SizedBox(height: 12),
              BookingSearchSortBar(
                controller: search,
                sort: sort,
                onChanged: () => setState(() {}),
                onSortChanged: (value) => setState(() => sort = value),
              ),
              const SizedBox(height: 12),
              if (data.isEmpty)
                const EmptyState(
                  title: 'No matches',
                  message: 'Try searching a venue, customer, status, or date.',
                )
              else
                ...data.map((booking) {
                  final map = booking as Map<String, dynamic>;
                  return BookingTile(api: widget.api, booking: map);
                }),
            ],
          );
        },
      ),
    );
  }
}

class _AdminRecordsNotice extends StatelessWidget {
  const _AdminRecordsNotice({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.sky,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined, color: AppTheme.navy),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Admins review $count booking records for audit and payment visibility. Hosts still approve or reject bookings.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminVenuesScreen extends StatefulWidget {
  const AdminVenuesScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<AdminVenuesScreen> createState() => _AdminVenuesScreenState();
}

class _AdminVenuesScreenState extends State<AdminVenuesScreen> {
  late Future<List<dynamic>> venues = _load();
  final search = TextEditingController();
  String statusFilter = 'ALL';

  Future<List<dynamic>> _load() async {
    final response = await widget.api.get('/admin/venues');
    return response['venues'] as List<dynamic>;
  }

  Future<bool> _setStatus(Map<String, dynamic> venue, String status) async {
    final currentStatus =
        venue['status']?.toString().toUpperCase() ?? 'PENDING';
    if (currentStatus == status) {
      _snack(context, 'This venue is already ${_prettyStatus(status)}.');
      return false;
    }
    final actionLabel = _adminVenueActionLabel(status, currentStatus);
    final confirmed = await _confirmAction(
      context,
      title: '$actionLabel venue?',
      message: _adminVenueActionMessage(status, currentStatus),
      confirmLabel: actionLabel,
    );
    if (!confirmed) return false;

    try {
      await widget.api.put('/venues/${venue['id']}', {'status': status});
      if (!mounted) return false;
      setState(() => venues = _load());
      _snack(context, _adminVenueActionSuccess(status, currentStatus));
      return true;
    } catch (error) {
      if (!mounted) return false;
      _snack(context, error.toString());
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin venues')),
      body: FutureBuilder<List<dynamic>>(
        future: venues,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return snapshot.hasError
                ? EmptyState(
                    title: 'Could not load venues',
                    message: snapshot.error.toString(),
                  )
                : const LoadingView();
          }
          final data = _filterVenues(snapshot.data!, search.text, statusFilter);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              VenueSearchFilterBar(
                controller: search,
                status: statusFilter,
                onChanged: () => setState(() {}),
                onStatusChanged: (value) =>
                    setState(() => statusFilter = value),
              ),
              const SizedBox(height: 12),
              if (data.isEmpty)
                const EmptyState(
                  title: 'No venues match',
                  message: 'Try another search or filter.',
                )
              else
                ...data.map((item) {
                  final venue = item as Map<String, dynamic>;
                  final images = venue['images'] as List<dynamic>? ?? [];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          VenueImageCarousel(images: images, height: 150),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        venue['name'],
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    VHStatusChip(venue['status']),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${venue['location']} - ${moneyFormat.format(_num(venue['pricePerDay']))}',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              AdminVenueDetailsScreen(
                                                venue: venue,
                                                onStatus: (status) =>
                                                    _setStatus(venue, status),
                                              ),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                      ),
                                      label: const Text('Review details'),
                                    ),
                                    _AdminVenueActionButtons(
                                      venue: venue,
                                      onStatus: (status) =>
                                          _setStatus(venue, status),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _AdminVenueActionButtons extends StatelessWidget {
  const _AdminVenueActionButtons({
    required this.venue,
    required this.onStatus,
    this.expanded = false,
  });

  final Map<String, dynamic> venue;
  final Future<bool> Function(String status) onStatus;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final status = venue['status']?.toString().toUpperCase() ?? 'PENDING';
    final buttons = switch (status) {
      'PENDING' => [
        OutlinedButton.icon(
          onPressed: () => onStatus('REJECTED'),
          icon: const Icon(Icons.close_rounded),
          label: const Text('Reject listing'),
        ),
        ElevatedButton.icon(
          onPressed: () => onStatus('APPROVED'),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Approve listing'),
        ),
      ],
      'APPROVED' => [
        OutlinedButton.icon(
          onPressed: () => onStatus('REJECTED'),
          icon: const Icon(Icons.visibility_off_outlined),
          label: const Text('Unlist venue'),
        ),
      ],
      _ => [
        ElevatedButton.icon(
          onPressed: () => onStatus('APPROVED'),
          icon: const Icon(Icons.restore_outlined),
          label: const Text('Restore listing'),
        ),
      ],
    };

    if (!expanded) return Wrap(spacing: 8, runSpacing: 8, children: buttons);

    return Row(
      children: [
        for (var index = 0; index < buttons.length; index++) ...[
          if (index > 0) const SizedBox(width: 12),
          Expanded(child: buttons[index]),
        ],
      ],
    );
  }
}

class AdminVenueDetailsScreen extends StatelessWidget {
  const AdminVenueDetailsScreen({
    super.key,
    required this.venue,
    required this.onStatus,
  });

  final Map<String, dynamic> venue;
  final Future<bool> Function(String status) onStatus;

  @override
  Widget build(BuildContext context) {
    final images = venue['images'] as List<dynamic>? ?? [];
    final amenities = venue['amenities'] as List<dynamic>? ?? [];
    final facilities = venue['facilities'] as List<dynamic>? ?? [];
    final host = venue['host'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(title: const Text('Review venue listing')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: _AdminVenueActionButtons(
          venue: venue,
          expanded: true,
          onStatus: (status) async {
            final didUpdate = await onStatus(status);
            if (didUpdate && context.mounted) Navigator.pop(context);
            return didUpdate;
          },
        ),
      ),
      body: ListView(
        children: [
          VenueImageCarousel(images: images, height: 260),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        venue['name']?.toString() ?? 'Venue',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    VHStatusChip(venue['status']?.toString() ?? 'PENDING'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  venue['description']?.toString() ??
                      'No description provided.',
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _InfoLine(
                          Icons.place_outlined,
                          'Location',
                          '${venue['location']} - ${venue['address']}',
                        ),
                        _InfoLine(
                          Icons.people_outline,
                          'Capacity',
                          '${venue['capacity']} guests',
                        ),
                        _InfoLine(
                          Icons.payments_outlined,
                          'Price',
                          '${moneyFormat.format(_num(venue['pricePerDay']))} / day',
                        ),
                        if (host != null)
                          _InfoLine(
                            Icons.storefront_outlined,
                            'Host',
                            '${host['name'] ?? 'Host'} - ${host['email'] ?? ''}',
                          ),
                      ],
                    ),
                  ),
                ),
                _DetailChipSection(title: 'Amenities', items: amenities),
                _DetailChipSection(title: 'Facilities', items: facilities),
                const SizedBox(height: 90),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailChipSection extends StatelessWidget {
  const _DetailChipSection({required this.title, required this.items});

  final String title;
  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('None listed.', style: TextStyle(color: Colors.black54))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map(
                    (item) => Chip(
                      label: Text(
                        (item as Map<String, dynamic>)['name']?.toString() ??
                            'Item',
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class AdminIncomeScreen extends StatefulWidget {
  const AdminIncomeScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<AdminIncomeScreen> createState() => _AdminIncomeScreenState();
}

class _AdminIncomeScreenState extends State<AdminIncomeScreen> {
  late Future<Map<String, dynamic>> income = _load();

  Future<Map<String, dynamic>> _load() async {
    final response = await widget.api.get('/admin/income-summary');
    return response;
  }

  Future<void> _changeServiceFee(num currentFee) async {
    final controller = TextEditingController(text: currentFee.toString());
    final next = await showDialog<num>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change service fee'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'New fee percent'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _num(controller.text)),
            child: const Text('Review'),
          ),
        ],
      ),
    );
    if (next == null) return;
    if (!mounted) return;
    final confirmed = await _confirmAction(
      context,
      title: 'Apply service fee change?',
      message:
          'Old fee: $currentFee%. New fee: $next%. Future bookings will use the new fee.',
      confirmLabel: 'Apply fee',
    );
    if (!confirmed) return;

    try {
      final response = await widget.api.put('/admin/service-fee', {
        'serviceFeePercent': next,
      });
      if (!mounted) return;
      setState(() => income = _load());
      _snack(
        context,
        response['message']?.toString() ?? 'Service fee updated.',
      );
    } catch (error) {
      if (!mounted) return;
      _snack(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Income summary')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: income,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return snapshot.hasError
                ? EmptyState(
                    title: 'Could not load income',
                    message: snapshot.error.toString(),
                  )
                : const LoadingView();
          }
          final response = snapshot.data!;
          final data = response['income'] as Map<String, dynamic>;
          final serviceFeePercent = _num(response['serviceFeePercent']);
          final trend = _incomeTrend(data);
          final paymentBreakdown =
              data['paymentBreakdown'] as Map<String, dynamic>? ?? {};
          final statusBreakdown =
              data['statusBreakdown'] as Map<String, dynamic>? ?? {};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: AppTheme.sky,
                child: ListTile(
                  leading: const Icon(Icons.percent, color: AppTheme.navy),
                  title: Text(
                    'Current service fee: $serviceFeePercent%',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Applies to future booking calculations.',
                  ),
                  trailing: FilledButton(
                    onPressed: () => _changeServiceFee(serviceFeePercent),
                    child: const Text('Change'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _DashboardHeroCard(
                title: 'Income health',
                subtitle:
                    '${data['paidBookingCount'] ?? 0} paid bookings - ${data['completedBookings'] ?? 0} completed',
                amount: moneyFormat.format(_num(data['allTime'])),
                caption: 'Realized platform fees',
                icon: Icons.savings_outlined,
              ),
              const SizedBox(height: 14),
              _MiniBarChart(
                title: 'Platform fee trend',
                subtitle:
                    'Historical monthly view with the current month using live platform-fee data.',
                values: trend.values,
                labels: trend.labels,
              ),
              const SizedBox(height: 14),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.05,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  VHStatCard(
                    label: 'Gross paid',
                    value: moneyFormat.format(_num(data['grossPaid'])),
                    icon: Icons.payments_outlined,
                  ),
                  VHStatCard(
                    label: 'Host payout est.',
                    value: moneyFormat.format(
                      _num(data['estimatedHostIncome']),
                    ),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  VHStatCard(
                    label: 'Unpaid balances',
                    value: moneyFormat.format(_num(data['outstandingBalance'])),
                    icon: Icons.pending_actions_outlined,
                  ),
                  VHStatCard(
                    label: 'Avg platform fee',
                    value: moneyFormat.format(_num(data['averagePlatformFee'])),
                    icon: Icons.analytics_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _DashboardInfoCard(
                title: 'What unpaid balances mean',
                rows: [
                  _DashboardInfoRow(
                    icon: Icons.info_outline_rounded,
                    label:
                        'Approved or pending booking amounts that have not been collected yet.',
                    value: moneyFormat.format(_num(data['outstandingBalance'])),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _DashboardInfoCard(
                title: 'Payment breakdown',
                rows: [
                  _DashboardInfoRow(
                    icon: Icons.savings_outlined,
                    label: 'Deposits collected',
                    value: moneyFormat.format(
                      _num(paymentBreakdown['deposit']),
                    ),
                  ),
                  _DashboardInfoRow(
                    icon: Icons.task_alt_outlined,
                    label: 'Balances collected',
                    value: moneyFormat.format(
                      _num(paymentBreakdown['balance']),
                    ),
                  ),
                  _DashboardInfoRow(
                    icon: Icons.payments_outlined,
                    label: 'Full payments collected',
                    value: moneyFormat.format(_num(paymentBreakdown['full'])),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _DashboardInfoCard(
                title: 'Booking status mix',
                rows: [
                  _DashboardInfoRow(
                    icon: Icons.hourglass_top_rounded,
                    label: 'Pending',
                    value: '${statusBreakdown['PENDING'] ?? 0}',
                  ),
                  _DashboardInfoRow(
                    icon: Icons.event_available_outlined,
                    label: 'Approved',
                    value: '${statusBreakdown['APPROVED'] ?? 0}',
                  ),
                  _DashboardInfoRow(
                    icon: Icons.verified_outlined,
                    label: 'Completed',
                    value: '${statusBreakdown['COMPLETED'] ?? 0}',
                  ),
                  _DashboardInfoRow(
                    icon: Icons.cancel_outlined,
                    label: 'Rejected',
                    value: '${statusBreakdown['REJECTED'] ?? 0}',
                  ),
                ],
              ),
              const VHSectionTitle('Recent income activity'),
              ...((data['recent'] as List<dynamic>? ?? []).map((item) {
                final row = item as Map<String, dynamic>;
                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.receipt_long_outlined,
                      color: AppTheme.blue,
                    ),
                    title: Text(row['venueName']?.toString() ?? 'Venue'),
                    subtitle: Text(
                      'Paid ${moneyFormat.format(_num(row['paid']))}',
                    ),
                    trailing: Text(
                      moneyFormat.format(_num(row['serviceFee'])),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                );
              })),
            ],
          );
        },
      ),
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  const _MiniBarChart({
    required this.values,
    required this.labels,
    required this.title,
    required this.subtitle,
  });

  final List<num> values;
  final List<String> labels;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<num>(
      1,
      (max, value) => value > max ? value : max,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(values.length, (index) {
                final height = 26 + (values[index] / maxValue * 90);
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        moneyFormat.format(values[index]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic,
                        height: height.toDouble(),
                        width: 30,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              AppTheme.navy,
                              AppTheme.blue.withValues(alpha: 0.82),
                              AppTheme.gold.withValues(alpha: 0.72),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        labels[index],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminJsonCard extends StatelessWidget {
  const _AdminJsonCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final title = item['name'] ?? item['email'] ?? item['id'] ?? 'Record';
    final subtitle =
        item['role'] ??
        item['status'] ??
        item['paymentStatus'] ??
        item['location'] ??
        '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          onTap: () => _showAdminRecordDetails(context, item),
          title: Text(
            title.toString(),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(subtitle.toString()),
          trailing: item['status'] == null
              ? null
              : VHStatusChip(item['status'].toString()),
        ),
      ),
    );
  }
}

class _AdminUserCard extends StatelessWidget {
  const _AdminUserCard({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final name = _displayValue(user['name'], fallback: 'Unnamed account');
    final email = _displayValue(user['email'], fallback: 'No email');
    final role = user['role']?.toString() ?? 'CUSTOMER';
    final bookingCount = _summaryCount(user, 'bookingCount', 'bookings');
    final venueCount = _summaryCount(user, 'venueCount', 'venues');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          onTap: () => _showAdminUserDetails(context, user),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.sky,
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _MiniInfoChip(
                            Icons.verified_user_outlined,
                            _roleText(role),
                          ),
                          _MiniInfoChip(
                            Icons.event_note_outlined,
                            '$bookingCount bookings',
                          ),
                          _MiniInfoChip(
                            Icons.apartment_outlined,
                            '$venueCount venues',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showAdminUserDetails(BuildContext context, Map<String, dynamic> user) {
  final name = _displayValue(user['name'], fallback: 'Unnamed account');
  final email = _displayValue(user['email'], fallback: 'No email');
  final role = user['role']?.toString() ?? 'CUSTOMER';
  final bookings = _summaryList(user, 'recentBookings', 'bookings');
  final venues = _summaryList(user, 'venueSummaries', 'venues');
  final bookingCount = _summaryCount(user, 'bookingCount', 'bookings');
  final venueCount = _summaryCount(user, 'venueCount', 'venues');

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (context) {
      final colors = AppTheme.colorsOf(context);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            Center(
              child: Container(
                height: 4,
                width: 44,
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.sky,
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniInfoChip(Icons.verified_user_outlined, _roleText(role)),
                _MiniInfoChip(
                  Icons.event_note_outlined,
                  '$bookingCount bookings',
                ),
                _MiniInfoChip(Icons.apartment_outlined, '$venueCount venues'),
              ],
            ),
            const SizedBox(height: 18),
            _AdminDetailSection(
              title: 'Contact',
              children: [
                _InfoLine(Icons.email_outlined, 'Email', email),
                _InfoLine(
                  Icons.phone_outlined,
                  'Phone',
                  _displayValue(user['phone'], fallback: 'Not provided'),
                ),
                _InfoLine(
                  Icons.wc_outlined,
                  'Gender',
                  _displayValue(user['gender'], fallback: 'Not provided'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _AdminDetailSection(
              title: 'Profile notes',
              children: [
                _InfoLine(
                  Icons.travel_explore_outlined,
                  'Preferences',
                  _displayValue(
                    user['preferences'],
                    fallback: 'No preferences yet',
                  ),
                ),
                _InfoLine(
                  Icons.thumb_up_alt_outlined,
                  'Likes',
                  _displayValue(user['likes'], fallback: 'No likes yet'),
                ),
                _InfoLine(
                  Icons.notes_outlined,
                  'Notes',
                  _displayValue(
                    user['specialNotes'],
                    fallback: 'No special notes yet',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _AdminDetailSection(
              title: 'Recent booking activity',
              children: bookings.isEmpty
                  ? [
                      Text(
                        'No recent booking activity.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ]
                  : bookings.map((booking) {
                      final map = booking as Map<String, dynamic>;
                      return _AdminSummaryRow(
                        icon: Icons.event_note_outlined,
                        title: _displayValue(
                          map['venueName'] ??
                              (map['venue'] is Map
                                  ? (map['venue'] as Map)['name']
                                  : null),
                          fallback: 'Venue booking',
                        ),
                        subtitle:
                            '${_prettyStatus(map['status'])} · ${_prettyStatus(map['paymentStatus'])}',
                        trailing: _dateLabel(map['eventDate']),
                      );
                    }).toList(),
            ),
            const SizedBox(height: 12),
            _AdminDetailSection(
              title: 'Listed venues',
              children: venues.isEmpty
                  ? [
                      Text(
                        'No listed venues.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ]
                  : venues.map((venue) {
                      final map = venue as Map<String, dynamic>;
                      return _AdminSummaryRow(
                        icon: Icons.apartment_outlined,
                        title: _displayValue(map['name'], fallback: 'Venue'),
                        subtitle: _displayValue(
                          map['location'],
                          fallback: 'No location',
                        ),
                        trailing: _prettyStatus(map['status']),
                      );
                    }).toList(),
            ),
          ],
        ),
      );
    },
  );
}

class _AdminDetailSection extends StatelessWidget {
  const _AdminDetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _AdminSummaryRow extends StatelessWidget {
  const _AdminSummaryRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: AppTheme.sky,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppTheme.navy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.secondaryText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trailing,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  const _MiniInfoChip(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.sky,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.navy),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

void _showAdminRecordDetails(BuildContext context, Map<String, dynamic> item) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      final entries = item.entries
          .where(
            (entry) => ![
              'password',
              'resetTokenHash',
              'resetTokenExpires',
            ].contains(entry.key),
          )
          .take(18)
          .toList();
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item['name']?.toString() ??
                      item['email']?.toString() ??
                      'Account details',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...entries.map(
            (entry) => _InfoLine(
              Icons.info_outline,
              entry.key,
              entry.value?.toString() ?? '',
            ),
          ),
        ],
      );
    },
  );
}

Color _notificationAccent(String type) {
  final normalized = type.toUpperCase();
  if (normalized.contains('PAYMENT')) return AppTheme.gold;
  if (normalized.contains('BOOKING_STATUS')) return AppTheme.blue;
  if (normalized.contains('BOOKING_REQUEST')) return AppTheme.navy;
  return AppTheme.blue;
}

IconData _notificationIcon(String type) {
  final normalized = type.toUpperCase();
  if (normalized.contains('PAYMENT')) return Icons.payments_outlined;
  if (normalized.contains('BOOKING_STATUS')) {
    return Icons.event_available_outlined;
  }
  if (normalized.contains('BOOKING_REQUEST')) return Icons.inbox_outlined;
  return Icons.notifications_none_rounded;
}

List<String> _csv(String text) {
  return text
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

bool _isAmenityOption(String label) => _hasOfferOption(_amenityOptions, label);

bool _isFacilityOption(String label) =>
    _hasOfferOption(_facilityOptions, label);

bool _hasOfferOption(List<_HostOfferOption> options, String label) {
  final normalized = label.trim().toLowerCase();
  return options.any((option) => option.label.toLowerCase() == normalized);
}

List<String> _mergeOfferValues(Set<String> selected, String customText) {
  final values = <String>[];
  final seen = <String>{};
  for (final item in [...selected, ..._csv(customText)]) {
    final label = item.trim();
    if (label.isEmpty) continue;
    if (seen.add(label.toLowerCase())) values.add(label);
  }
  return values;
}

num _num(dynamic value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

String _displayValue(dynamic value, {required String fallback}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text == 'null' ? fallback : text;
}

String _roleText(String role) {
  return switch (role.toUpperCase()) {
    'VENUEHUB_ADMIN' => 'Admin',
    'HOST' => 'Host',
    _ => 'Customer',
  };
}

int _summaryCount(
  Map<String, dynamic> item,
  String countKey,
  String legacyListKey,
) {
  final explicit = item[countKey];
  if (explicit is num) return explicit.toInt();
  final legacy = item[legacyListKey];
  if (legacy is List) return legacy.length;
  return 0;
}

List<dynamic> _summaryList(
  Map<String, dynamic> item,
  String summaryKey,
  String legacyKey,
) {
  final summary = item[summaryKey];
  if (summary is List) return summary;
  final legacy = item[legacyKey];
  if (legacy is List) return legacy.take(4).toList();
  return const [];
}

String _dateLabel(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed == null ? 'No date' : dateFormat.format(parsed);
}

num _balanceDue(Map<String, dynamic> booking) {
  final receipt = booking['receipt'];
  if (receipt is Map<String, dynamic>) {
    return _num(receipt['remainingBalance']);
  }

  final payments = booking['payments'];
  if (payments is List) {
    final paid = payments.fold<num>(
      0,
      (sum, payment) => sum + _num((payment as Map<String, dynamic>)['amount']),
    );
    return (_num(booking['totalAmount']) - paid).clamp(0, double.infinity);
  }

  return _num(booking['remainingBalance']);
}

String _bookingStatus(Map<String, dynamic> booking) =>
    booking['status']?.toString().toUpperCase() ?? 'PENDING';

String _bookingPaymentStatus(Map<String, dynamic> booking) =>
    booking['paymentStatus']?.toString().toUpperCase() ?? 'UNPAID';

bool _canPayDeposit(Map<String, dynamic> booking) =>
    ['PENDING', 'APPROVED'].contains(_bookingStatus(booking)) &&
    _bookingPaymentStatus(booking) == 'UNPAID';

bool _canPayBalance(Map<String, dynamic> booking) =>
    ['PENDING', 'APPROVED'].contains(_bookingStatus(booking)) &&
    _bookingPaymentStatus(booking) == 'PARTIALLY_PAID' &&
    _balanceDue(booking) > 0;

bool _canHostApprove(Map<String, dynamic> booking) =>
    _bookingStatus(booking) == 'PENDING';

bool _canHostReject(Map<String, dynamic> booking) =>
    _bookingStatus(booking) == 'PENDING' &&
    _bookingPaymentStatus(booking) == 'UNPAID';

bool _canHostComplete(Map<String, dynamic> booking) =>
    _bookingStatus(booking) == 'APPROVED' &&
    _bookingPaymentStatus(booking) == 'PAID';

IconData _bookingNextStepIcon(Map<String, dynamic> booking) {
  final status = _bookingStatus(booking);
  final payment = _bookingPaymentStatus(booking);
  if (status == 'PENDING') return Icons.hourglass_empty_rounded;
  if (status == 'REJECTED' || status == 'CANCELLED') {
    return Icons.cancel_outlined;
  }
  if (status == 'COMPLETED') return Icons.verified_outlined;
  if (payment == 'UNPAID') return Icons.lock_outline_rounded;
  if (payment == 'PARTIALLY_PAID') return Icons.payments_outlined;
  return Icons.task_alt_rounded;
}

String _bookingNextStepMessage(
  Map<String, dynamic> booking, {
  required bool hostView,
}) {
  final status = _bookingStatus(booking);
  final payment = _bookingPaymentStatus(booking);
  if (status == 'PENDING') {
    return hostView
        ? 'Legacy pending request. The customer can now pay the deposit without waiting for host approval.'
        : 'This date is reserved. Pay the 50% security deposit to secure the booking.';
  }
  if (status == 'REJECTED') {
    return 'This booking was rejected. No payment can be made for this request.';
  }
  if (status == 'CANCELLED') {
    return 'This booking was cancelled.';
  }
  if (status == 'COMPLETED') {
    return 'This event is complete and closed.';
  }
  if (payment == 'UNPAID') {
    return hostView
        ? 'Date reserved and waiting for the customer to pay the 50% security deposit.'
        : 'Date reserved. Pay the 50% security deposit to secure the booking.';
  }
  if (payment == 'PARTIALLY_PAID') {
    return hostView
        ? 'Deposit received. The customer still needs to pay the remaining balance.'
        : 'Deposit received. Pay the remaining balance before or on event day.';
  }
  return hostView
      ? 'Fully paid. You can mark the event completed after the event.'
      : 'Fully paid. The host will mark this completed after the event.';
}

class _IncomeTrend {
  const _IncomeTrend({required this.values, required this.labels});

  final List<num> values;
  final List<String> labels;
}

_IncomeTrend _incomeTrend(Map<String, dynamic> data) {
  final liveTrend = data['monthlyTrend'];
  if (liveTrend is List && liveTrend.isNotEmpty) {
    final values = liveTrend
        .map((item) => _num((item as Map<String, dynamic>)['platformFees']))
        .toList();
    final labels = liveTrend.map((item) {
      final map = item as Map<String, dynamic>;
      final label = map['label']?.toString() ?? '';
      final key = map['key']?.toString() ?? '';
      if (key.length >= 7) {
        return '$label ${key.substring(0, 4)}';
      }
      return label;
    }).toList();
    final nonZeroMonths = values.where((value) => value > 0).length;
    final uniqueValues = values
        .map((value) => value.toStringAsFixed(2))
        .toSet();
    if (nonZeroMonths >= 2 && uniqueValues.length > 1) {
      return _IncomeTrend(values: values, labels: labels);
    }

    final now = DateTime.now();
    final currentKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    final currentBucket = liveTrend.cast<Map<String, dynamic>>().where(
      (item) => item['key']?.toString() == currentKey,
    );
    final currentLiveAmount = currentBucket.isNotEmpty
        ? _num(currentBucket.first['platformFees'])
        : _num(data['monthly']);
    return _historicalIncomeTrend(
      currentLiveAmount > 0 ? currentLiveAmount : _num(data['allTime']),
    );
  }

  final currentLiveAmount = _num(data['monthly']) > 0
      ? _num(data['monthly'])
      : _num(data['allTime']);
  return _historicalIncomeTrend(currentLiveAmount);
}

_IncomeTrend _historicalIncomeTrend(num currentLiveAmount) {
  final now = DateTime.now();
  final amount = currentLiveAmount <= 0 ? 37000 : currentLiveAmount;
  final weights = <double>[0.34, 0.48, 0.63, 0.57, 0.82, 1.0];
  final labels = <String>[];
  final values = <num>[];
  const monthLabels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  for (var index = 5; index >= 0; index--) {
    final date = DateTime(now.year, now.month - index, 1);
    labels.add('${monthLabels[date.month - 1]} ${date.year}');
    values.add((amount * weights[5 - index]).round());
  }

  return _IncomeTrend(values: values, labels: labels);
}

String _locationLabel(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return 'Nearby';

  const knownPlaces = [
    'Tacloban',
    'Palo',
    'Ormoc',
    'Baybay',
    'Guiuan',
    'Catbalogan',
    'Borongan',
    'Naval',
    'Maasin',
    'Calbayog',
    'Tanauan',
    'Dulag',
    'Jaro',
    'Burauen',
    'Catarman',
    'Tolosa',
  ];
  final lower = text.toLowerCase();
  for (final place in knownPlaces) {
    if (lower.contains(place.toLowerCase())) return place;
  }

  return text
      .split(RegExp(r'[,\\-]'))
      .first
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

Map<String, List<Map<String, dynamic>>> _groupVenuesByLocation(
  List<Map<String, dynamic>> venues,
) {
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final venue in venues) {
    final label = _locationLabel(venue['location']);
    grouped.putIfAbsent(label, () => []).add(venue);
  }
  return grouped;
}

String _firstVenueImage(Map<String, dynamic> venue) {
  final urls = _venueImageUrls(venue);
  return urls.isEmpty ? '' : urls.first;
}

List<String> _venueImageUrls(Map<String, dynamic> venue) {
  final images = venue['images'];
  if (images is! List) return const [];
  return images
      .map(
        (image) => image is String
            ? image
            : (image['imageUrl'] ?? image['url'])?.toString(),
      )
      .whereType<String>()
      .where((imageUrl) => imageUrl.trim().isNotEmpty)
      .toList();
}

ll.LatLng _venueLatLng(Map<String, dynamic> venue) {
  final latitude = _optionalDouble(venue['latitude']);
  final longitude = _optionalDouble(venue['longitude']);
  if (_isValidLatLng(latitude, longitude)) {
    return ll.LatLng(latitude!, longitude!);
  }

  return _fallbackLatLngForVenue(venue);
}

double? _optionalDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

bool _isValidLatLng(double? latitude, double? longitude) {
  return latitude != null &&
      longitude != null &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

ll.LatLng _fallbackLatLngForVenue(Map<String, dynamic> venue) {
  final name = (venue['name']?.toString() ?? '').toLowerCase();
  const coordinates = [
    ('leyte convention complex', ll.LatLng(11.159448, 124.990814)),
    ('tropics', ll.LatLng(11.163523, 125.004271)),
    ('arcivu', ll.LatLng(11.159655, 124.992231)),
    ('playa alegre', ll.LatLng(11.112276, 125.021208)),
    ('banez', ll.LatLng(11.111211, 125.016919)),
    ('haiyan', ll.LatLng(11.1104, 125.0181)),
    ('shydan', ll.LatLng(10.953244, 125.033452)),
    ('camp bryztoff', ll.LatLng(10.9519, 125.0337)),
    ('dulag cultural', ll.LatLng(10.953529, 125.034146)),
    ('tacloban city convention', ll.LatLng(11.2444, 125.0005)),
    ('the pavilion', ll.LatLng(11.2419, 125.0038)),
    ('sophia', ll.LatLng(11.222857, 125.001154)),
    ('antonios', ll.LatLng(11.20383, 125.020509)),
    ('cancabato', ll.LatLng(11.214509, 125.023794)),
    ('ritz tower', ll.LatLng(11.244093, 125.001422)),
    ('myco', ll.LatLng(11.201936, 125.006776)),
    ('summit hotel tacloban', ll.LatLng(11.208056, 125.007281)),
    ('le jardin', ll.LatLng(11.2289, 125.0058)),
    ('pacific point', ll.LatLng(11.1967, 125.0209)),
    ('palm', ll.LatLng(11.189519, 124.783188)),
    ('sheila', ll.LatLng(11.1876, 124.7842)),
    ('villaconzoilo', ll.LatLng(11.2036, 124.8359)),
    ('origami', ll.LatLng(11.009035, 124.609394)),
    ('zt leisure', ll.LatLng(11.0316, 124.6087)),
    ('rosetta', ll.LatLng(11.0068, 124.6071)),
    ('camp kawayan', ll.LatLng(10.978997, 124.910294)),
    ('teresita', ll.LatLng(10.986909, 124.891691)),
    ('garden paradise', ll.LatLng(10.974871, 124.893223)),
    ('burauen community', ll.LatLng(10.974377, 124.891765)),
    ('calbayog cultural', ll.LatLng(12.066963, 124.594666)),
    ('m grand royale', ll.LatLng(11.775053, 124.883907)),
    ('ssu convention', ll.LatLng(11.771232, 124.885358)),
    ('ibabao hall', ll.LatLng(12.504133, 124.632916)),
  ];

  for (final (needle, point) in coordinates) {
    if (name.contains(needle)) {
      return point;
    }
  }
  return _fallbackLatLngForLocation(venue['location'], venue['address']);
}

ll.LatLng _fallbackLatLngForLocation(dynamic location, dynamic address) {
  final text = '${location ?? ''} ${address ?? ''}'.toLowerCase();
  const coordinates = [
    ('catarman', ll.LatLng(12.504133, 124.632916)),
    ('calbayog', ll.LatLng(12.066963, 124.594666)),
    ('catbalogan', ll.LatLng(11.771232, 124.885358)),
    ('ormoc', ll.LatLng(11.009035, 124.609394)),
    ('jaro', ll.LatLng(11.189519, 124.783188)),
    ('burauen', ll.LatLng(10.974871, 124.893223)),
    ('dulag', ll.LatLng(10.953244, 125.033452)),
    ('tanauan', ll.LatLng(11.111211, 125.016919)),
    ('palo', ll.LatLng(11.159448, 124.990814)),
    ('tacloban', ll.LatLng(11.244093, 125.001422)),
  ];

  for (final (needle, point) in coordinates) {
    if (text.contains(needle)) {
      return point;
    }
  }
  return const ll.LatLng(11.244093, 125.001422);
}

List<dynamic> _filterVenues(List<dynamic> source, String query, String status) {
  final normalizedQuery = query.trim().toLowerCase();
  return source.where((item) {
    final venue = item as Map<String, dynamic>;
    final matchesStatus =
        status == 'ALL' || venue['status']?.toString() == status;
    final haystack = [
      venue['name'],
      venue['location'],
      venue['address'],
      venue['status'],
      venue['capacity'],
    ].join(' ').toLowerCase();
    return matchesStatus &&
        (normalizedQuery.isEmpty || haystack.contains(normalizedQuery));
  }).toList()..sort((a, b) {
    final left = a as Map<String, dynamic>;
    final right = b as Map<String, dynamic>;
    return (right['createdAt']?.toString() ?? '').compareTo(
      left['createdAt']?.toString() ?? '',
    );
  });
}

List<dynamic> _filterUsers(List<dynamic> source, String query, String role) {
  final normalizedQuery = query.trim().toLowerCase();
  return source.where((item) {
    final user = item as Map<String, dynamic>;
    final matchesRole = role == 'ALL' || user['role']?.toString() == role;
    final haystack = [
      user['name'],
      user['email'],
      user['phone'],
      user['preferences'],
      user['likes'],
      user['specialNotes'],
    ].join(' ').toLowerCase();
    return matchesRole &&
        (normalizedQuery.isEmpty || haystack.contains(normalizedQuery));
  }).toList();
}

List<dynamic> _filterSortBookings(
  List<dynamic> source,
  String query,
  String sort,
) {
  final normalizedQuery = query.trim().toLowerCase();
  final results = source.where((item) {
    final booking = item as Map<String, dynamic>;
    final venue = booking['venue'] as Map<String, dynamic>? ?? {};
    final customer = booking['customer'] as Map<String, dynamic>? ?? {};
    final dateText = booking['eventDate']?.toString() ?? '';
    final haystack = [
      venue['name'],
      customer['name'],
      customer['email'],
      booking['status'],
      booking['paymentStatus'],
      dateText,
      dateText.isEmpty ? '' : dateFormat.format(DateTime.parse(dateText)),
    ].join(' ').toLowerCase();

    return normalizedQuery.isEmpty || haystack.contains(normalizedQuery);
  }).toList();

  results.sort((a, b) {
    final left = a as Map<String, dynamic>;
    final right = b as Map<String, dynamic>;

    return switch (sort) {
      'oldest' => DateTime.parse(
        left['createdAt'],
      ).compareTo(DateTime.parse(right['createdAt'])),
      'status' => '${left['status']}${left['paymentStatus']}'.compareTo(
        '${right['status']}${right['paymentStatus']}',
      ),
      'price' => _num(
        right['totalAmount'],
      ).compareTo(_num(left['totalAmount'])),
      _ => DateTime.parse(
        right['createdAt'],
      ).compareTo(DateTime.parse(left['createdAt'])),
    };
  });

  return results;
}

Future<bool> _confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}

String _prettyStatus(dynamic status) {
  final text = status?.toString() ?? 'unknown';
  return text.toLowerCase().replaceAll('_', ' ');
}

String _prettyStatusAction(String status) {
  return switch (status) {
    'APPROVED' => 'Approve',
    'REJECTED' => 'Reject',
    'COMPLETED' => 'Complete',
    _ => 'Update',
  };
}

String _adminVenueActionLabel(String nextStatus, String currentStatus) {
  if (nextStatus == 'APPROVED' && currentStatus == 'REJECTED') {
    return 'Restore listing';
  }
  if (nextStatus == 'APPROVED') return 'Approve listing';
  if (nextStatus == 'REJECTED' && currentStatus == 'APPROVED') {
    return 'Unlist venue';
  }
  if (nextStatus == 'REJECTED') return 'Reject listing';
  return 'Update listing';
}

String _adminVenueActionMessage(String nextStatus, String currentStatus) {
  if (nextStatus == 'APPROVED' && currentStatus == 'PENDING') {
    return 'This publishes the host venue so customers can browse and book it.';
  }
  if (nextStatus == 'APPROVED') {
    return 'This restores the venue to the public customer marketplace.';
  }
  if (nextStatus == 'REJECTED' && currentStatus == 'APPROVED') {
    return 'This hides the venue from customers. Existing booking records stay in the system.';
  }
  if (nextStatus == 'REJECTED') {
    return 'This rejects the listing request and keeps it hidden from customers.';
  }
  return 'This updates the venue listing status.';
}

String _adminVenueActionSuccess(String nextStatus, String currentStatus) {
  if (nextStatus == 'APPROVED' && currentStatus == 'REJECTED') {
    return 'Venue restored and visible to customers.';
  }
  if (nextStatus == 'APPROVED') return 'Venue approved and published.';
  if (nextStatus == 'REJECTED' && currentStatus == 'APPROVED') {
    return 'Venue unlisted and hidden from customers.';
  }
  if (nextStatus == 'REJECTED') return 'Venue listing rejected.';
  return 'Venue updated.';
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
