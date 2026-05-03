import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 30),
            const Center(child: VenueHubLogo(size: 118)),
            const SizedBox(height: 26),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
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
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: loading ? null : _login,
              child: Text(loading ? 'Signing in...' : 'Login'),
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
            const SizedBox(height: 18),
            _DemoLoginCard(
              onPick: (demoEmail) {
                email.text = demoEmail;
                password.text = 'password123';
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DemoLoginCard extends StatelessWidget {
  const _DemoLoginCard({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Demo accounts',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Customer'),
                  onPressed: () => onPick('customer@venuehub.test'),
                ),
                ActionChip(
                  label: const Text('Host'),
                  onPressed: () => onPick('host@venuehub.test'),
                ),
                ActionChip(
                  label: const Text('Admin'),
                  onPressed: () => onPick('admin@venuehub.test'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
  final phone = TextEditingController();
  String role = 'CUSTOMER';
  bool loading = false;

  Future<void> _register() async {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: email,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phone,
            decoration: const InputDecoration(labelText: 'Contact number'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'Account type'),
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
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: loading ? null : _register,
            child: Text(loading ? 'Creating...' : 'Register'),
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      VenueBrowseScreen(api: widget.api),
      MyBookingsScreen(api: widget.api),
      ProfileScreen(
        api: widget.api,
        user: widget.user,
        onLogout: widget.onLogout,
        onUserUpdated: widget.onUserUpdated,
      ),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (value) => setState(() => index = value),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search_rounded),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_month_rounded),
            label: 'Bookings',
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

class VenueBrowseScreen extends StatefulWidget {
  const VenueBrowseScreen({super.key, required this.api});

  final ApiClient api;

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
                hintText: 'Tacloban, Palo, Ormoc...',
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

  void _selectLocation(String value) {
    setState(() => selectedLocation = value);
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
              final locations = _venueLocations(cards);
              final displayed = selectedLocation == 'All'
                  ? cards
                  : cards
                        .where(
                          (venue) =>
                              _locationLabel(venue['location']) ==
                              selectedLocation,
                        )
                        .toList();
              final grouped = _groupVenuesByLocation(displayed);
              final sectionEntries = grouped.entries.take(5).toList();

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _ExploreSearchHeader(
                    query: query.text,
                    location: location.text,
                    onTap: _openSearchSheet,
                  ),
                  _ExploreTabs(),
                  LocationCategoryRail(
                    locations: locations,
                    selected: selectedLocation,
                    onSelected: _selectLocation,
                  ),
                  if (cards.isEmpty)
                    const EmptyState(
                      title: 'No venues yet',
                      message: 'Approved venues will appear here.',
                    )
                  else if (displayed.isEmpty)
                    EmptyState(
                      title: 'No venues in $selectedLocation',
                      message:
                          'Try another location or use search to widen the results.',
                    )
                  else ...[
                    ContinueSearchingCard(
                      location: selectedLocation == 'All'
                          ? _locationLabel(displayed.first['location'])
                          : selectedLocation,
                      imageUrl: _firstVenueImage(displayed.first),
                      onTap: _openSearchSheet,
                    ),
                    VenueHorizontalSection(
                      title: selectedLocation == 'All'
                          ? 'Recommended event places'
                          : '$selectedLocation event places',
                      venues: displayed.take(8).toList(),
                      api: widget.api,
                    ),
                    ...sectionEntries.map(
                      (entry) => VenueHorizontalSection(
                        title: '${entry.key} venues',
                        venues: entry.value,
                        api: widget.api,
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

class _ExploreSearchHeader extends StatelessWidget {
  const _ExploreSearchHeader({
    required this.query,
    required this.location,
    required this.onTap,
  });

  final String query;
  final String location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = query.trim().isEmpty && location.trim().isEmpty
        ? 'Where is your next event?'
        : [
            if (query.trim().isNotEmpty) query.trim(),
            if (location.trim().isNotEmpty) location.trim(),
          ].join(' in ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.95, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) =>
            Transform.scale(scale: value, child: child),
        child: Material(
          color: Colors.white,
          elevation: 10,
          shadowColor: AppTheme.navy.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppTheme.sky,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: AppTheme.navy,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExploreTabs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const tabs = [
      (Icons.home_work_outlined, 'Venues', true),
      (Icons.celebration_outlined, 'Packages', false),
      (Icons.room_service_outlined, 'Services', false),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final tab in tabs)
                Column(
                  children: [
                    Icon(
                      tab.$1,
                      color: tab.$3 ? AppTheme.ink : Colors.black45,
                      size: 30,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tab.$2,
                      style: TextStyle(
                        fontWeight: tab.$3 ? FontWeight.w900 : FontWeight.w700,
                        color: tab.$3 ? AppTheme.ink : Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      height: 3,
                      width: tab.$3 ? 58 : 0,
                      decoration: BoxDecoration(
                        color: AppTheme.ink,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const Divider(height: 16),
        ],
      ),
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
  });

  final String title;
  final List<Map<String, dynamic>> venues;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    if (venues.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.sky,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 282,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              scrollDirection: Axis.horizontal,
              itemCount: venues.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) =>
                  VenueMiniCard(venue: venues[index], api: api),
            ),
          ),
        ],
      ),
    );
  }
}

class VenueMiniCard extends StatelessWidget {
  const VenueMiniCard({super.key, required this.venue, required this.api});

  final Map<String, dynamic> venue;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _firstVenueImage(venue);

    return SizedBox(
      width: 190,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                VenueDetailsScreen(api: api, venueId: venue['id'] as String),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: VenueImageView(
                    imageUrl: imageUrl,
                    height: 176,
                    width: 190,
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Icon(
                    Icons.favorite_border_rounded,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              venue['name']?.toString() ?? 'Venue',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '${_locationLabel(venue['location'])} - ${venue['capacity']} guests',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              '${moneyFormat.format(_num(venue['pricePerDay']))} / day',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppTheme.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VenueCard extends StatelessWidget {
  const VenueCard({super.key, required this.venue, required this.api});

  final Map<String, dynamic> venue;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    final images = venue['images'] as List<dynamic>? ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                VenueDetailsScreen(api: api, venueId: venue['id'] as String),
          ),
        ),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VenueImageCarousel(images: images, height: 190),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            venue['name'] ?? '',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        Text('${venue['averageRating'] ?? 0}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${venue['location']} - up to ${venue['capacity']} guests',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${moneyFormat.format(_num(venue['pricePerDay']))} / day',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VenueDetailsScreen extends StatefulWidget {
  const VenueDetailsScreen({
    super.key,
    required this.api,
    required this.venueId,
  });

  final ApiClient api;
  final String venueId;

  @override
  State<VenueDetailsScreen> createState() => _VenueDetailsScreenState();
}

class _VenueDetailsScreenState extends State<VenueDetailsScreen> {
  late Future<Map<String, dynamic>> venue = _load();

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
        final images = venue['images'] as List<dynamic>? ?? [];

        return Scaffold(
          appBar: AppBar(title: Text(venue['name'] ?? 'Venue')),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookingScreen(api: widget.api, venue: venue),
                ),
              ),
              child: const Text('Choose date and book'),
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
                    Text(
                      venue['name'],
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${venue['location']} - ${venue['address']}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    Text(venue['description'] ?? ''),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoPill(Icons.people, '${venue['capacity']} guests'),
                        _InfoPill(
                          Icons.payments,
                          moneyFormat.format(_num(venue['pricePerDay'])),
                        ),
                        _InfoPill(
                          Icons.star,
                          '${venue['averageRating']} rating',
                        ),
                      ],
                    ),
                    _ChipList(
                      title: 'Amenities',
                      items: venue['amenities'] as List<dynamic>? ?? [],
                    ),
                    _ChipList(
                      title: 'Facilities',
                      items: venue['facilities'] as List<dynamic>? ?? [],
                    ),
                    _Reviews(reviews: venue['reviews'] as List<dynamic>? ?? []),
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

class _InfoPill extends StatelessWidget {
  const _InfoPill(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 16), label: Text(label));
  }
}

class _ChipList extends StatelessWidget {
  const _ChipList({required this.title, required this.items});

  final String title;
  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: items
              .map((item) => Chip(label: Text(item['name'].toString())))
              .toList(),
        ),
      ],
    );
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({required this.reviews});

  final List<dynamic> reviews;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const Text(
          'Guest feedback',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        if (reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'No reviews yet.',
              style: TextStyle(color: Colors.black54),
            ),
          )
        else
          ...reviews.map(
            (review) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text('${review['rating']} stars'),
              subtitle: Text(review['comment']?.toString() ?? ''),
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: DateTime.now().add(const Duration(days: 14)),
    );
    if (picked != null) setState(() => eventDate = picked);
  }

  Future<void> _book() async {
    if (eventDate == null) {
      _snack(context, 'Please choose an event date.');
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
      appBar: AppBar(title: const Text('Booking request')),
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
                    'Deposit is non-refundable. Remaining balance is due before or on event day.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month),
            label: Text(
              eventDate == null
                  ? 'Choose event date'
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
            child: Text(loading ? 'Submitting...' : 'Submit booking request'),
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
    final methods = [
      'VISA',
      'MASTERCARD',
      'PAYPAL',
      'GCASH',
      'MAYA',
      'EWALLET',
    ];
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.black54)),
                  Text(
                    moneyFormat.format(amountDue),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(note),
                ],
              ),
            ),
          ),
          const VHSectionTitle('Payment method'),
          ...methods.map(
            (item) => Card(
              child: ListTile(
                onTap: () => setState(() => method = item),
                leading: Icon(_paymentIcon(item)),
                title: Text(item.replaceAll('_', ' ')),
                trailing: Icon(
                  method == item
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: method == item ? AppTheme.blue : Colors.black38,
                ),
              ),
            ),
          ),
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified, color: Colors.green, size: 52),
                  const SizedBox(height: 12),
                  const Text(
                    'Payment approved',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  Text(receipt['receiptNumber']?.toString() ?? ''),
                  const Divider(height: 32),
                  _MoneyRow('Subtotal', _num(receipt['subtotal'])),
                  _MoneyRow('Deposit paid', _num(receipt['depositPaid'])),
                  _MoneyRow(
                    'Remaining balance',
                    _num(receipt['remainingBalance']),
                  ),
                  _MoneyRow('App service fee', _num(receipt['serviceFee'])),
                  const SizedBox(height: 12),
                  Text(receipt['securityNote']?.toString() ?? ''),
                  if (emailMessage != null) ...[
                    const Divider(height: 32),
                    Row(
                      children: [
                        Icon(
                          emailStatus == 'sent'
                              ? Icons.mark_email_read_outlined
                              : Icons.email_outlined,
                          color: emailStatus == 'sent'
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(emailMessage!)),
                      ],
                    ),
                  ],
                ],
              ),
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

  Future<List<dynamic>> _load() async {
    final response = await widget.api.get('/bookings/my');
    return response['bookings'] as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
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
          final data = _filterSortBookings(raw, search.text, sort);
          return RefreshIndicator(
            onRefresh: () async => setState(() => bookings = _load()),
            child: ListView(
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
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
        child: Padding(
          padding: EdgeInsets.zero,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          venue['name'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dateFormat.format(
                            DateTime.parse(booking['eventDate']),
                          ),
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            VHStatusChip(
                              booking['status']?.toString() ?? 'PENDING',
                            ),
                            VHStatusChip(paymentStatus),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.black38,
                  ),
                ],
              ),
            ),
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
          if (!hostControls && paymentStatus == 'UNPAID')
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentScreen(api: api, booking: booking),
                ),
              ),
              icon: const Icon(Icons.lock_outline),
              label: const Text('Pay 50% deposit'),
            ),
          if (!hostControls && paymentStatus == 'PARTIALLY_PAID')
            ElevatedButton.icon(
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
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Pay remaining balance'),
            ),
          if (!hostControls && paymentStatus == 'PAID')
            const Text(
              'Fully paid. The host can mark this booking completed after the event.',
              style: TextStyle(color: Colors.black54),
            ),
          if (hostControls)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => onStatus?.call('APPROVED'),
                  child: const Text('Approve'),
                ),
                OutlinedButton(
                  onPressed: () => onStatus?.call('REJECTED'),
                  child: const Text('Reject'),
                ),
                ElevatedButton(
                  onPressed: () => onStatus?.call('COMPLETED'),
                  child: const Text('Complete'),
                ),
              ],
            ),
        ],
      ),
    );
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
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'name': name.text.trim(),
                'phone': phone.text.trim(),
                'gender': gender.text.trim(),
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
                  size: 168,
                ),
                Positioned(
                  bottom: -18,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.ink,
                      elevation: 6,
                      shadowColor: Colors.black26,
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
                        : const Icon(Icons.photo_camera_rounded),
                    label: Text(savingPhoto ? 'Saving...' : 'Add'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 42),
          Center(
            child: Text(
              user['name'] ?? '',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          Center(
            child: Text(
              user['role'] ?? '',
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'My profile',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hosts and customers can see your profile details to help build trust before an event booking.',
            style: TextStyle(color: Colors.black54, height: 1.45),
          ),
          const SizedBox(height: 24),
          _ProfileDetailCard(
            children: [
              _ProfileDetailTile(
                icon: Icons.email_outlined,
                title: user['email'] ?? '',
                subtitle: 'Email address',
              ),
              _ProfileDetailTile(
                icon: Icons.phone_outlined,
                title: user['phone'] ?? 'Add contact number',
                subtitle: 'Contact info',
              ),
              _ProfileDetailTile(
                icon: Icons.wc_outlined,
                title: user['gender'] ?? 'Add gender',
                subtitle: 'Personal detail',
              ),
              _ProfileDetailTile(
                icon: Icons.badge_outlined,
                title: user['role'] ?? '',
                subtitle: 'Account type',
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _editDetails,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit account details'),
          ),
          const SizedBox(height: 10),
          _ProfileDetailCard(
            children: const [
              _ProfileDetailTile(
                icon: Icons.travel_explore_outlined,
                title: 'Where I want to host or celebrate',
                subtitle: 'Tacloban, Palo, Ormoc, and nearby places',
              ),
              _ProfileDetailTile(
                icon: Icons.work_outline_rounded,
                title: 'My work',
                subtitle: 'Add work or organization details',
              ),
              _ProfileDetailTile(
                icon: Icons.favorite_border_rounded,
                title: 'Favorite event style',
                subtitle: 'Garden, hall, beach, or intimate dinner',
              ),
            ],
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangePasswordScreen(api: widget.api),
              ),
            ),
            icon: const Icon(Icons.lock_reset),
            label: const Text('Change password'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
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

class _ProfileDetailCard extends StatelessWidget {
  const _ProfileDetailCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(height: 1, indent: 68),
          ],
        ],
      ),
    );
  }
}

class _ProfileDetailTile extends StatelessWidget {
  const _ProfileDetailTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minLeadingWidth: 30,
      leading: Icon(icon, color: AppTheme.ink),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
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
      body: pages[index],
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
          return GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: 2,
            childAspectRatio: 1.05,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              VHStatCard(
                label: 'Paid bookings',
                value: '${data['paidBookings']}',
                icon: Icons.event_available,
              ),
              VHStatCard(
                label: 'Gross paid',
                value: moneyFormat.format(_num(data['grossPaid'])),
                icon: Icons.payments,
              ),
              VHStatCard(
                label: 'App fees',
                value: moneyFormat.format(_num(data['estimatedPlatformFees'])),
                icon: Icons.receipt,
              ),
              VHStatCard(
                label: 'Host income',
                value: moneyFormat.format(_num(data['estimatedHostIncome'])),
                icon: Icons.trending_up,
              ),
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
      await widget.api.put('/bookings/$id/status', {'status': status});
      if (!mounted) return;
      setState(() => bookings = _load());
      _snack(context, 'Booking updated to ${_prettyStatus(status)}.');
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
          final data = snapshot.data!;
          if (data.isEmpty) {
            return const EmptyState(
              title: 'No venues listed',
              message: 'Tap Add venue to create your first listing.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: data.map((item) {
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
                            Text(
                              '${venue['location']} - ${moneyFormat.format(_num(venue['pricePerDay']))}',
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              children: [
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
            }).toList(),
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

class _AddVenueScreenState extends State<AddVenueScreen> {
  final name = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final capacity = TextEditingController();
  final location = TextEditingController();
  final address = TextEditingController();
  final amenities = TextEditingController(
    text: 'Air conditioning, Parking, Catering partner',
  );
  final facilities = TextEditingController(
    text: 'Main hall, Sound system, Prep room',
  );
  final imagePicker = ImagePicker();
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
            .map((item) => item['imageUrl'].toString())
            .where((item) => item.isNotEmpty),
      );
    amenities.text = ((venue['amenities'] as List<dynamic>? ?? []).map(
      (item) => item['name'].toString(),
    )).join(', ');
    facilities.text = ((venue['facilities'] as List<dynamic>? ?? []).map(
      (item) => item['name'].toString(),
    )).join(', ');
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

  Future<void> _save() async {
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
        'amenities': _csv(amenities.text),
        'facilities': _csv(facilities.text),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.venue == null ? 'Add venue' : 'Edit venue'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Venue name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: description,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Price per day'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: capacity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Capacity'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: location,
            decoration: const InputDecoration(labelText: 'Location'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: address,
            decoration: const InputDecoration(labelText: 'Address'),
          ),
          const SizedBox(height: 10),
          _VenuePhotoPicker(
            images: selectedImages,
            onAdd: _chooseImages,
            onRemove: _removeImage,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: amenities,
            decoration: const InputDecoration(
              labelText: 'Amenities, comma separated',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: facilities,
            decoration: const InputDecoration(
              labelText: 'Facilities, comma separated',
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: loading ? null : _save,
            child: Text(
              loading
                  ? 'Saving...'
                  : widget.venue == null
                  ? 'Submit venue'
                  : 'Save changes',
            ),
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
      body: pages[index],
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
            label: 'Bookings',
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
          return GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: 2,
            childAspectRatio: 1.05,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              VHStatCard(
                label: 'Users',
                value: '${data['totalUsers']}',
                icon: Icons.group,
              ),
              VHStatCard(
                label: 'Hosts',
                value: '${data['totalHosts']}',
                icon: Icons.store,
              ),
              VHStatCard(
                label: 'Venues',
                value: '${data['totalVenues']}',
                icon: Icons.location_city,
              ),
              VHStatCard(
                label: 'Bookings',
                value: '${data['totalBookings']}',
                icon: Icons.event,
              ),
              VHStatCard(
                label: 'Platform income',
                value: moneyFormat.format(_num(data['platformIncome'])),
                icon: Icons.savings,
              ),
              const VHStatCard(
                label: 'Service fee',
                value: '10%',
                icon: Icons.percent,
              ),
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
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: data
                .map(
                  (item) => _AdminJsonCard(item: item as Map<String, dynamic>),
                )
                .toList(),
          );
        },
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

  Future<void> _status(String id, String status) async {
    final confirmed = await _confirmAction(
      context,
      title: '${_prettyStatusAction(status)} booking?',
      message:
          'This will update the booking status to ${_prettyStatus(status)} for everyone.',
      confirmLabel: _prettyStatusAction(status),
    );
    if (!confirmed) return;

    try {
      await widget.api.put('/bookings/$id/status', {'status': status});
      if (!mounted) return;
      setState(() => bookings = _load());
      _snack(context, 'Booking updated to ${_prettyStatus(status)}.');
    } catch (error) {
      if (!mounted) return;
      _snack(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin bookings')),
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

class AdminVenuesScreen extends StatefulWidget {
  const AdminVenuesScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<AdminVenuesScreen> createState() => _AdminVenuesScreenState();
}

class _AdminVenuesScreenState extends State<AdminVenuesScreen> {
  late Future<List<dynamic>> venues = _load();

  Future<List<dynamic>> _load() async {
    final response = await widget.api.get('/admin/venues');
    return response['venues'] as List<dynamic>;
  }

  Future<bool> _setStatus(String id, String status) async {
    final confirmed = await _confirmAction(
      context,
      title: '${_prettyStatusAction(status)} venue?',
      message: 'This venue listing will be marked ${_prettyStatus(status)}.',
      confirmLabel: _prettyStatusAction(status),
    );
    if (!confirmed) return false;

    try {
      await widget.api.put('/venues/$id', {'status': status});
      if (!mounted) return false;
      setState(() => venues = _load());
      _snack(context, 'Venue updated to ${_prettyStatus(status)}.');
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: snapshot.data!.map((item) {
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
                                ElevatedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdminVenueDetailsScreen(
                                        venue: venue,
                                        onStatus: (status) =>
                                            _setStatus(venue['id'], status),
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.visibility_outlined),
                                  label: const Text('Review details'),
                                ),
                                OutlinedButton(
                                  onPressed: () =>
                                      _setStatus(venue['id'], 'APPROVED'),
                                  child: const Text('Approve'),
                                ),
                                OutlinedButton(
                                  onPressed: () =>
                                      _setStatus(venue['id'], 'REJECTED'),
                                  child: const Text('Reject'),
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
            }).toList(),
          );
        },
      ),
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
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final didUpdate = await onStatus('REJECTED');
                  if (didUpdate && context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.close),
                label: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final didUpdate = await onStatus('APPROVED');
                  if (didUpdate && context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.check),
                label: const Text('Approve'),
              ),
            ),
          ],
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
    return response['income'] as Map<String, dynamic>;
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
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              VHStatCard(
                label: 'Weekly platform income',
                value: moneyFormat.format(_num(data['weekly'])),
                icon: Icons.calendar_view_week,
              ),
              const SizedBox(height: 12),
              VHStatCard(
                label: 'Monthly platform income',
                value: moneyFormat.format(_num(data['monthly'])),
                icon: Icons.calendar_month,
              ),
              const SizedBox(height: 12),
              VHStatCard(
                label: 'Annual platform income',
                value: moneyFormat.format(_num(data['annual'])),
                icon: Icons.stacked_line_chart,
              ),
              const SizedBox(height: 12),
              VHStatCard(
                label: 'All-time platform income',
                value: moneyFormat.format(_num(data['allTime'])),
                icon: Icons.savings,
              ),
            ],
          );
        },
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

IconData _paymentIcon(String method) {
  return switch (method) {
    'VISA' || 'MASTERCARD' => Icons.credit_card,
    'PAYPAL' => Icons.account_balance_wallet,
    'GCASH' || 'MAYA' => Icons.phone_android,
    _ => Icons.wallet,
  };
}

List<String> _csv(String text) {
  return text
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

num _num(dynamic value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
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

List<String> _venueLocations(List<Map<String, dynamic>> venues) {
  const preferred = [
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
    'Tolosa',
  ];
  final labels = venues
      .map((venue) => _locationLabel(venue['location']))
      .toSet();
  final extras = labels.where((label) => !preferred.contains(label)).toList()
    ..sort();
  final ordered = [...preferred.where(labels.contains), ...extras];

  return ordered.isEmpty ? preferred : ordered;
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
  final images = venue['images'];
  if (images is List && images.isNotEmpty) {
    final first = images.first;
    if (first is Map<String, dynamic>) {
      return first['url']?.toString() ?? '';
    }
  }
  return '';
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

String _prettyStatus(String status) {
  return status.toLowerCase().replaceAll('_', ' ');
}

String _prettyStatusAction(String status) {
  return switch (status) {
    'APPROVED' => 'Approve',
    'REJECTED' => 'Reject',
    'COMPLETED' => 'Complete',
    _ => 'Update',
  };
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
