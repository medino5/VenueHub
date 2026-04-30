import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
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
              : RoleHome(api: api, user: user!, onLogout: _logout),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF5A5F), Color(0xFFFFB067)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
                child: const Icon(Icons.location_city, size: 64, color: AppTheme.coral),
              ),
              const SizedBox(height: 18),
              const Text('VenueHub', style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900)),
              const Text('Find the perfect event place', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api, required this.onAuthenticated});

  final ApiClient api;
  final Future<void> Function(String token, Map<String, dynamic> user) onAuthenticated;

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
      await widget.onAuthenticated(response['token'] as String, response['user'] as Map<String, dynamic>);
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
            const Text('VenueHub', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: AppTheme.ink)),
            const SizedBox(height: 8),
            const Text('Book event venues with a polished demo flow for customers, hosts, and admins.'),
            const SizedBox(height: 26),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            const SizedBox(height: 18),
            ElevatedButton(onPressed: loading ? null : _login, child: Text(loading ? 'Signing in...' : 'Login')),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RegisterScreen(api: widget.api, onAuthenticated: widget.onAuthenticated)),
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
            Text('API: ${AppConfig.apiBaseUrl}', style: const TextStyle(color: Colors.black45, fontSize: 12)),
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
            const Text('Demo accounts', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(label: const Text('Customer'), onPressed: () => onPick('customer@venuehub.test')),
                ActionChip(label: const Text('Host'), onPressed: () => onPick('host@venuehub.test')),
                ActionChip(label: const Text('Admin'), onPressed: () => onPick('admin@venuehub.test')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.api, required this.onAuthenticated});

  final ApiClient api;
  final Future<void> Function(String token, Map<String, dynamic> user) onAuthenticated;

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
      await widget.onAuthenticated(response['token'] as String, response['user'] as Map<String, dynamic>);
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
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
          const SizedBox(height: 12),
          TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 12),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'Contact number')),
          const SizedBox(height: 12),
          TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'Account type'),
            items: const [
              DropdownMenuItem(value: 'CUSTOMER', child: Text('Customer')),
              DropdownMenuItem(value: 'HOST', child: Text('Host / Venue Lister')),
              DropdownMenuItem(value: 'VENUEHUB_ADMIN', child: Text('VenueHub Admin')),
            ],
            onChanged: (value) => setState(() => role = value ?? 'CUSTOMER'),
          ),
          const SizedBox(height: 18),
          ElevatedButton(onPressed: loading ? null : _register, child: Text(loading ? 'Creating...' : 'Register')),
        ],
      ),
    );
  }
}

class RoleHome extends StatelessWidget {
  const RoleHome({super.key, required this.api, required this.user, required this.onLogout});

  final ApiClient api;
  final Map<String, dynamic> user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return switch (user['role']) {
      'HOST' => HostHome(api: api, user: user, onLogout: onLogout),
      'VENUEHUB_ADMIN' => AdminHome(api: api, user: user, onLogout: onLogout),
      _ => CustomerHome(api: api, user: user, onLogout: onLogout),
    };
  }
}

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key, required this.api, required this.user, required this.onLogout});

  final ApiClient api;
  final Map<String, dynamic> user;
  final VoidCallback onLogout;

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
      ProfileScreen(user: widget.user, onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.event_note), label: 'Bookings'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
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
  late Future<List<dynamic>> venues = _loadVenues();

  Future<List<dynamic>> _loadVenues() async {
    final response = await widget.api.get('/venues');
    return response['venues'] as List<dynamic>;
  }

  Future<void> _search() async {
    final response = await widget.api.get('/venues/search?query=${Uri.encodeComponent(query.text)}&location=${Uri.encodeComponent(location.text)}');
    setState(() => venues = Future.value(response['venues'] as List<dynamic>));
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
              if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView();
              if (snapshot.hasError) return EmptyState(title: 'API unavailable', message: snapshot.error.toString());
              final data = snapshot.data ?? [];

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _HeroSearch(query: query, location: location, onSearch: _search),
                  const VHSectionTitle('Popular venues'),
                  if (data.isEmpty)
                    const EmptyState(title: 'No venues yet', message: 'Approved venues will appear here.')
                  else
                    ...data.map((venue) => VenueCard(venue: venue as Map<String, dynamic>, api: widget.api)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeroSearch extends StatelessWidget {
  const _HeroSearch({required this.query, required this.location, required this.onSearch});

  final TextEditingController query;
  final TextEditingController location;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(colors: [Color(0xFF182230), Color(0xFF007C89)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Where is the next celebration?', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          TextField(controller: query, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Venue name')),
          const SizedBox(height: 10),
          TextField(controller: location, decoration: const InputDecoration(prefixIcon: Icon(Icons.place), hintText: 'Location')),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onSearch, child: const Text('Search venues')),
        ],
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
    final imageUrl = images.isNotEmpty ? images.first['imageUrl'] as String : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VenueDetailsScreen(api: api, venueId: venue['id'] as String))),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null)
                Image.network(imageUrl, height: 190, width: double.infinity, fit: BoxFit.cover)
              else
                Container(height: 190, color: Colors.black12, child: const Center(child: Icon(Icons.image))),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(venue['name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        Text('${venue['averageRating'] ?? 0}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${venue['location']} - up to ${venue['capacity']} guests', style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 8),
                    Text('${moneyFormat.format(_num(venue['pricePerDay']))} / day', style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.coral)),
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
  const VenueDetailsScreen({super.key, required this.api, required this.venueId});

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
          return Scaffold(appBar: AppBar(), body: snapshot.hasError ? EmptyState(title: 'Could not load venue', message: snapshot.error.toString()) : const LoadingView());
        }

        final venue = snapshot.data!;
        final images = venue['images'] as List<dynamic>? ?? [];

        return Scaffold(
          appBar: AppBar(title: Text(venue['name'] ?? 'Venue')),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingScreen(api: widget.api, venue: venue))),
              child: const Text('Choose date and book'),
            ),
          ),
          body: ListView(
            children: [
              SizedBox(
                height: 260,
                child: PageView(
                  children: images.isEmpty
                      ? [Container(color: Colors.black12, child: const Icon(Icons.image, size: 60))]
                      : images.map((image) => Image.network(image['imageUrl'] as String, fit: BoxFit.cover)).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(venue['name'], style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text('${venue['location']} - ${venue['address']}', style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 12),
                    Text(venue['description'] ?? ''),
                    const SizedBox(height: 18),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _InfoPill(Icons.people, '${venue['capacity']} guests'),
                      _InfoPill(Icons.payments, moneyFormat.format(_num(venue['pricePerDay']))),
                      _InfoPill(Icons.star, '${venue['averageRating']} rating'),
                    ]),
                    _ChipList(title: 'Amenities', items: venue['amenities'] as List<dynamic>? ?? []),
                    _ChipList(title: 'Facilities', items: venue['facilities'] as List<dynamic>? ?? []),
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
        Wrap(spacing: 8, children: items.map((item) => Chip(label: Text(item['name'].toString()))).toList()),
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
        const Text('Guest feedback', style: TextStyle(fontWeight: FontWeight.w900)),
        if (reviews.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 8), child: Text('No reviews yet.', style: TextStyle(color: Colors.black54)))
        else
          ...reviews.map((review) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text('${review['rating']} stars'),
                subtitle: Text(review['comment']?.toString() ?? ''),
              )),
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
        MaterialPageRoute(builder: (_) => PaymentScreen(api: widget.api, booking: response['booking'] as Map<String, dynamic>)),
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
          Text(widget.venue['name'], style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
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
                  const Text('Deposit is non-refundable. Remaining balance is due before or on event day.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month),
            label: Text(eventDate == null ? 'Choose event date' : dateFormat.format(eventDate!)),
          ),
          const SizedBox(height: 12),
          TextField(controller: notes, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Notes for host')),
          const SizedBox(height: 18),
          ElevatedButton(onPressed: loading ? null : _book, child: Text(loading ? 'Submitting...' : 'Submit booking request')),
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
          Text(moneyFormat.format(value), style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.api, required this.booking});

  final ApiClient api;
  final Map<String, dynamic> booking;

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
        'paymentType': 'DEPOSIT',
      });
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ReceiptScreen(receipt: response['receipt'] as Map<String, dynamic>, booking: response['booking'] as Map<String, dynamic>)));
    } catch (error) {
      _snack(context, error.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final methods = ['VISA', 'MASTERCARD', 'PAYPAL', 'GCASH', 'MAYA', 'EWALLET'];
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
                  const Text('Amount due today', style: TextStyle(color: Colors.black54)),
                  Text(moneyFormat.format(_num(widget.booking['depositAmount'])), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('This simulated transaction records the 50% non-refundable security deposit.'),
                ],
              ),
            ),
          ),
          const VHSectionTitle('Payment method'),
          ...methods.map((item) => Card(
                child: ListTile(
                  onTap: () => setState(() => method = item),
                  leading: Icon(_paymentIcon(item)),
                  title: Text(item.replaceAll('_', ' ')),
                  trailing: Icon(
                    method == item ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: method == item ? AppTheme.coral : Colors.black38,
                  ),
                ),
              )),
          const SizedBox(height: 18),
          ElevatedButton(onPressed: loading ? null : _pay, child: Text(loading ? 'Processing...' : 'Pay simulated deposit')),
        ],
      ),
    );
  }
}

class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key, required this.receipt, required this.booking});

  final Map<String, dynamic> receipt;
  final Map<String, dynamic> booking;

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
                  const Text('Payment approved', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  Text(receipt['receiptNumber']?.toString() ?? ''),
                  const Divider(height: 32),
                  _MoneyRow('Subtotal', _num(receipt['subtotal'])),
                  _MoneyRow('Deposit paid', _num(receipt['depositPaid'])),
                  _MoneyRow('Remaining balance', _num(receipt['remainingBalance'])),
                  _MoneyRow('App service fee', _num(receipt['serviceFee'])),
                  const SizedBox(height: 12),
                  Text(receipt['securityNote']?.toString() ?? ''),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(onPressed: () => Navigator.popUntil(context, (route) => route.isFirst), child: const Text('Back to home')),
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
          if (!snapshot.hasData) return snapshot.hasError ? EmptyState(title: 'Could not load bookings', message: snapshot.error.toString()) : const LoadingView();
          final data = snapshot.data!;
          if (data.isEmpty) return const EmptyState(title: 'No bookings', message: 'Your venue reservations will show here.');
          return RefreshIndicator(
            onRefresh: () async => setState(() => bookings = _load()),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: data.map((booking) => BookingTile(api: widget.api, booking: booking as Map<String, dynamic>)).toList(),
            ),
          );
        },
      ),
    );
  }
}

class BookingTile extends StatelessWidget {
  const BookingTile({super.key, required this.api, required this.booking, this.hostControls = false, this.onStatus});

  final ApiClient api;
  final Map<String, dynamic> booking;
  final bool hostControls;
  final Future<void> Function(String status)? onStatus;

  @override
  Widget build(BuildContext context) {
    final venue = booking['venue'] as Map<String, dynamic>;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(venue['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                  VHStatusChip(booking['status']?.toString() ?? 'PENDING'),
                ],
              ),
              const SizedBox(height: 6),
              Text('Event: ${dateFormat.format(DateTime.parse(booking['eventDate']))}'),
              Text('Payment: ${booking['paymentStatus']}'),
              Text('Deposit: ${moneyFormat.format(_num(booking['depositAmount']))}'),
              const SizedBox(height: 12),
              if (!hostControls && booking['paymentStatus'] == 'UNPAID')
                OutlinedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(api: api, booking: booking))),
                  child: const Text('Pay deposit'),
                ),
              if (hostControls)
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(onPressed: () => onStatus?.call('APPROVED'), child: const Text('Approve')),
                    OutlinedButton(onPressed: () => onStatus?.call('REJECTED'), child: const Text('Reject')),
                    OutlinedButton(onPressed: () => onStatus?.call('COMPLETED'), child: const Text('Complete')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.user, required this.onLogout});

  final Map<String, dynamic> user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(radius: 46, backgroundImage: user['profileImageUrl'] == null ? null : NetworkImage(user['profileImageUrl'] as String), child: user['profileImageUrl'] == null ? const Icon(Icons.person, size: 48) : null),
          const SizedBox(height: 16),
          Center(child: Text(user['name'] ?? '', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900))),
          Center(child: Text(user['role'] ?? '', style: const TextStyle(color: Colors.black54))),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(leading: const Icon(Icons.email), title: Text(user['email'] ?? '')),
                ListTile(leading: const Icon(Icons.phone), title: Text(user['phone'] ?? 'No phone yet')),
                ListTile(leading: const Icon(Icons.wc), title: Text(user['gender'] ?? 'No gender set')),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(onPressed: onLogout, icon: const Icon(Icons.logout), label: const Text('Logout')),
        ],
      ),
    );
  }
}

class HostHome extends StatefulWidget {
  const HostHome({super.key, required this.api, required this.user, required this.onLogout});

  final ApiClient api;
  final Map<String, dynamic> user;
  final VoidCallback onLogout;

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
      ProfileScreen(user: widget.user, onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Host'),
          NavigationDestination(icon: Icon(Icons.event_available), label: 'Bookings'),
          NavigationDestination(icon: Icon(Icons.add_business), label: 'Venues'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
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
          if (!snapshot.hasData) return snapshot.hasError ? EmptyState(title: 'Could not load summary', message: snapshot.error.toString()) : const LoadingView();
          final data = snapshot.data!;
          return GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: 2,
            childAspectRatio: 1.05,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              VHStatCard(label: 'Paid bookings', value: '${data['paidBookings']}', icon: Icons.event_available),
              VHStatCard(label: 'Gross paid', value: moneyFormat.format(_num(data['grossPaid'])), icon: Icons.payments),
              VHStatCard(label: 'App fees', value: moneyFormat.format(_num(data['estimatedPlatformFees'])), icon: Icons.receipt),
              VHStatCard(label: 'Host income', value: moneyFormat.format(_num(data['estimatedHostIncome'])), icon: Icons.trending_up),
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

  Future<List<dynamic>> _load() async {
    final response = await widget.api.get('/bookings/host');
    return response['bookings'] as List<dynamic>;
  }

  Future<void> _status(String id, String status) async {
    await widget.api.put('/bookings/$id/status', {'status': status});
    setState(() => bookings = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Host bookings')),
      body: FutureBuilder<List<dynamic>>(
        future: bookings,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return snapshot.hasError ? EmptyState(title: 'Could not load host bookings', message: snapshot.error.toString()) : const LoadingView();
          final data = snapshot.data!;
          if (data.isEmpty) return const EmptyState(title: 'No requests yet', message: 'Customer booking requests for your venues will appear here.');
          return ListView(
            padding: const EdgeInsets.all(16),
            children: data.map((booking) {
              final map = booking as Map<String, dynamic>;
              return BookingTile(api: widget.api, booking: map, hostControls: true, onStatus: (status) => _status(map['id'] as String, status));
            }).toList(),
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
    await widget.api.delete('/venues/$id');
    setState(() => venues = _load());
  }

  Future<void> _openForm([Map<String, dynamic>? venue]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AddVenueScreen(api: widget.api, venue: venue)));
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
          if (!snapshot.hasData) return snapshot.hasError ? EmptyState(title: 'Could not load venues', message: snapshot.error.toString()) : const LoadingView();
          final data = snapshot.data!;
          if (data.isEmpty) return const EmptyState(title: 'No venues listed', message: 'Tap Add venue to create your first listing.');
          return ListView(
            padding: const EdgeInsets.all(16),
            children: data.map((item) {
              final venue = item as Map<String, dynamic>;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [Expanded(child: Text(venue['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), VHStatusChip(venue['status'])]),
                      Text('${venue['location']} - ${moneyFormat.format(_num(venue['pricePerDay']))}'),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, children: [
                        OutlinedButton(onPressed: () => _openForm(venue), child: const Text('Edit')),
                        OutlinedButton(onPressed: () => _delete(venue['id'] as String), child: const Text('Delete')),
                      ]),
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
  final images = TextEditingController(text: 'https://images.unsplash.com/photo-1519167758481-83f29c8f8c17?auto=format&fit=crop&w=1200&q=80');
  final amenities = TextEditingController(text: 'Air conditioning, Parking, Catering partner');
  final facilities = TextEditingController(text: 'Main hall, Sound system, Prep room');
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
    images.text = ((venue['images'] as List<dynamic>? ?? []).map((item) => item['imageUrl'].toString())).join(', ');
    amenities.text = ((venue['amenities'] as List<dynamic>? ?? []).map((item) => item['name'].toString())).join(', ');
    facilities.text = ((venue['facilities'] as List<dynamic>? ?? []).map((item) => item['name'].toString())).join(', ');
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
        'images': _csv(images.text),
        'amenities': _csv(amenities.text),
        'facilities': _csv(facilities.text),
      };

      if (widget.venue == null) {
        await widget.api.post('/venues', payload);
      } else {
        await widget.api.put('/venues/${widget.venue!['id']}', payload);
      }

      if (!mounted) return;
      _snack(context, widget.venue == null ? 'Venue submitted for admin approval.' : 'Venue updated.');
      for (final controller in [name, description, price, capacity, location, address]) {
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
      appBar: AppBar(title: Text(widget.venue == null ? 'Add venue' : 'Edit venue')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Venue name')),
          const SizedBox(height: 10),
          TextField(controller: description, minLines: 3, maxLines: 4, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 10),
          TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price per day')),
          const SizedBox(height: 10),
          TextField(controller: capacity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacity')),
          const SizedBox(height: 10),
          TextField(controller: location, decoration: const InputDecoration(labelText: 'Location')),
          const SizedBox(height: 10),
          TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
          const SizedBox(height: 10),
          TextField(controller: images, decoration: const InputDecoration(labelText: 'Image URLs, comma separated')),
          const SizedBox(height: 10),
          TextField(controller: amenities, decoration: const InputDecoration(labelText: 'Amenities, comma separated')),
          const SizedBox(height: 10),
          TextField(controller: facilities, decoration: const InputDecoration(labelText: 'Facilities, comma separated')),
          const SizedBox(height: 18),
          ElevatedButton(onPressed: loading ? null : _save, child: Text(loading ? 'Saving...' : widget.venue == null ? 'Submit venue' : 'Save changes')),
        ],
      ),
    );
  }
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key, required this.api, required this.user, required this.onLogout});

  final ApiClient api;
  final Map<String, dynamic> user;
  final VoidCallback onLogout;

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      AdminDashboard(api: widget.api),
      AdminListScreen(api: widget.api, title: 'Users', endpoint: '/admin/users', listKey: 'users'),
      AdminVenuesScreen(api: widget.api),
      AdminListScreen(api: widget.api, title: 'Bookings', endpoint: '/admin/bookings', listKey: 'bookings'),
      AdminIncomeScreen(api: widget.api),
      ProfileScreen(user: widget.user, onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard), label: 'Dash'),
          NavigationDestination(icon: Icon(Icons.group), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.location_city), label: 'Venues'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Bookings'),
          NavigationDestination(icon: Icon(Icons.analytics), label: 'Income'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Me'),
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
          if (!snapshot.hasData) return snapshot.hasError ? EmptyState(title: 'Could not load dashboard', message: snapshot.error.toString()) : const LoadingView();
          final data = snapshot.data!;
          return GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: 2,
            childAspectRatio: 1.05,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              VHStatCard(label: 'Users', value: '${data['totalUsers']}', icon: Icons.group),
              VHStatCard(label: 'Hosts', value: '${data['totalHosts']}', icon: Icons.store),
              VHStatCard(label: 'Venues', value: '${data['totalVenues']}', icon: Icons.location_city),
              VHStatCard(label: 'Bookings', value: '${data['totalBookings']}', icon: Icons.event),
              VHStatCard(label: 'Platform income', value: moneyFormat.format(_num(data['platformIncome'])), icon: Icons.savings),
              const VHStatCard(label: 'Service fee', value: '10%', icon: Icons.percent),
            ],
          );
        },
      ),
    );
  }
}

class AdminListScreen extends StatefulWidget {
  const AdminListScreen({super.key, required this.api, required this.title, required this.endpoint, required this.listKey});

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
          if (!snapshot.hasData) return snapshot.hasError ? EmptyState(title: 'Could not load ${widget.title}', message: snapshot.error.toString()) : const LoadingView();
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: data.map((item) => _AdminJsonCard(item: item as Map<String, dynamic>)).toList(),
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

  Future<void> _setStatus(String id, String status) async {
    await widget.api.put('/venues/$id', {'status': status});
    setState(() => venues = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin venues')),
      body: FutureBuilder<List<dynamic>>(
        future: venues,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return snapshot.hasError ? EmptyState(title: 'Could not load venues', message: snapshot.error.toString()) : const LoadingView();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: snapshot.data!.map((item) {
              final venue = item as Map<String, dynamic>;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [Expanded(child: Text(venue['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), VHStatusChip(venue['status'])]),
                      Text('${venue['location']} - ${moneyFormat.format(_num(venue['pricePerDay']))}'),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, children: [
                        OutlinedButton(onPressed: () => _setStatus(venue['id'], 'APPROVED'), child: const Text('Approve')),
                        OutlinedButton(onPressed: () => _setStatus(venue['id'], 'REJECTED'), child: const Text('Reject')),
                      ]),
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
          if (!snapshot.hasData) return snapshot.hasError ? EmptyState(title: 'Could not load income', message: snapshot.error.toString()) : const LoadingView();
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              VHStatCard(label: 'Weekly platform income', value: moneyFormat.format(_num(data['weekly'])), icon: Icons.calendar_view_week),
              const SizedBox(height: 12),
              VHStatCard(label: 'Monthly platform income', value: moneyFormat.format(_num(data['monthly'])), icon: Icons.calendar_month),
              const SizedBox(height: 12),
              VHStatCard(label: 'Annual platform income', value: moneyFormat.format(_num(data['annual'])), icon: Icons.stacked_line_chart),
              const SizedBox(height: 12),
              VHStatCard(label: 'All-time platform income', value: moneyFormat.format(_num(data['allTime'])), icon: Icons.savings),
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
    final subtitle = item['role'] ?? item['status'] ?? item['paymentStatus'] ?? item['location'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          title: Text(title.toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(subtitle.toString()),
          trailing: item['status'] == null ? null : VHStatusChip(item['status'].toString()),
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
  return text.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
}

num _num(dynamic value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
