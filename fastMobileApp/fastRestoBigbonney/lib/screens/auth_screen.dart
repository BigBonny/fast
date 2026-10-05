import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../provider.dart';
import '../resto_provider.dart';
import 'role_selection_screen.dart';
import '../theme.dart';

class AuthScreen extends StatefulWidget {
  final String? initialRole; // 'CLIENT', 'RESTAURANT' or 'LIVREUR'

  const AuthScreen({super.key, this.initialRole});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  // Login fields
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();

  // Register fields
  final _registerName = TextEditingController();
  final _registerEmail = TextEditingController();
  final _registerPhone = TextEditingController();
  final _registerPassword = TextEditingController();

  bool _obscureLoginPwd = true;
  bool _obscureRegisterPwd = true;

  // Restaurant-specific fields
  final _restoName = TextEditingController();
  final _restoAddress = TextEditingController();
  final _restoCity = TextEditingController();
  final _restoCuisine = TextEditingController();
  bool _showRestoFields = false;
  String _driverType = 'OCCASIONAL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _showRestoFields = widget.initialRole == 'RESTAURANT';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _registerName.dispose();
    _registerEmail.dispose();
    _registerPhone.dispose();
    _registerPassword.dispose();
    _restoName.dispose();
    _restoAddress.dispose();
    _restoCity.dispose();
    _restoCuisine.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _loginEmail.text.trim(),
      _loginPassword.text,
    );

    if (success && mounted) {
      _navigateToShell();
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      email: _registerEmail.text.trim(),
      password: _registerPassword.text,
      name: _registerName.text.trim(),
      phone: _registerPhone.text.trim(),
      role: widget.initialRole ?? 'CLIENT',
      driverType: widget.initialRole == 'LIVREUR' ? _driverType : null,
    );

    if (success && mounted) {
      _navigateToShell();
    }
  }

  void _navigateToShell() {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    // Sync user data to FASTProvider
    final fastProv = context.read<FASTProvider>();
    fastProv.syncFromAuth(
      id: user.id,
      name: user.name,
      email: user.email,
      phone: user.phone,
      points: user.points,
    );

    final isResto = auth.isRestaurant;
    // An owner who chose "Mode Client" stays on the client side.
    final goClient = isResto && fastProv.viewAsClient;

    // Load data from API after auth
    if (!user.isStaff) fastProv.loadFromApi();

    if (isResto && !goClient) {
      // Sync resto provider
      context.read<RestoProvider>().stopPolling();
    }

    // Signed in from the client form but the email belongs to a FAST Pro
    // account — explain the mode switch instead of confusingly landing
    // on the restaurant side.
    if (isResto && (widget.initialRole ?? 'CLIENT') == 'CLIENT') {
      fastProv.showToast('⚡ Compte FAST Pro', fastProv.tr('err_resto_account'));
    }

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final fast = context.watch<FASTProvider>();
    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        );
      },
      child: Scaffold(
        backgroundColor: context.fast.bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.fast.t1),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RoleSelectionScreen(),
                  ),
                );
              }
            },
          ),
          title: Text(
            _showRestoFields
                ? fast.tr('space_pro')
                : widget.initialRole == 'LIVREUR'
                ? fast.tr('space_driver')
                : fast.tr('space_client'),
            style: TextStyle(
              color: context.fast.t1,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  indicatorColor: Color(0xFFF59E0B),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: context.fast.line,
                  labelColor: context.fast.t1,
                  unselectedLabelColor: context.fast.t2,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  tabs: [
                    Tab(text: fast.tr('login_tab')),
                    Tab(text: fast.tr('register_tab')),
                  ],
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildLoginForm(), _buildRegisterForm()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    final fast = context.watch<FASTProvider>();
    return Form(
      key: _loginFormKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(
              controller: _loginEmail,
              label: fast.tr('email'),
              hint: 'adresse@exemple.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return fast.tr('err_email_required');
                }
                if (!v.contains('@')) return fast.tr('err_email_invalid');
                return null;
              },
            ),
            SizedBox(height: 20),
            _buildTextField(
              controller: _loginPassword,
              label: fast.tr('password'),
              hint: '••••••••',
              icon: Icons.lock_outlined,
              obscureText: _obscureLoginPwd,
              suffix: IconButton(
                icon: Icon(
                  _obscureLoginPwd ? Icons.visibility_off : Icons.visibility,
                  color: context.fast.t3,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureLoginPwd = !_obscureLoginPwd),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return fast.tr('err_pwd_required');
                return null;
              },
            ),
            SizedBox(height: 32),
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.error != null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      auth.error!,
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                return ElevatedButton(
                  onPressed: auth.isBusy
                      ? null
                      : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFF59E0B),
                    foregroundColor: FASTBrand.onAmber,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: auth.isBusy
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: FASTBrand.onAmber,
                          ),
                        )
                      : Text(
                          fast.tr('login_btn'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                );
              },
            ),
            _buildGoogleButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    final fast = context.watch<FASTProvider>();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Divider(color: context.fast.line)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  fast.tr('or'),
                  style: TextStyle(color: context.fast.t3, fontSize: 12),
                ),
              ),
              Expanded(child: Divider(color: context.fast.line)),
            ],
          ),
          const SizedBox(height: 16),
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              return OutlinedButton(
                onPressed: auth.isBusy
                    ? null
                    : () async {
                        final ok = await auth.signInWithGoogle(
                          role: widget.initialRole ?? 'CLIENT',
                        );
                        if (ok && mounted) _navigateToShell();
                      },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: context.fast.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4285F4),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        'G',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      fast.tr('google'),
                      style: TextStyle(
                        color: context.fast.t1,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    final fast = context.watch<FASTProvider>();
    return Form(
      key: _registerFormKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLanguagePicker(),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _registerName,
              label: fast.tr('name'),
              hint: 'Jean Dupont',
              icon: Icons.person_outlined,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return fast.tr('err_name_required');
                }
                return null;
              },
            ),
            SizedBox(height: 20),
            _buildTextField(
              controller: _registerEmail,
              label: fast.tr('email'),
              hint: 'adresse@exemple.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return fast.tr('err_email_required');
                }
                if (!v.contains('@')) return fast.tr('err_email_invalid');
                return null;
              },
            ),
            SizedBox(height: 20),
            _buildTextField(
              controller: _registerPhone,
              label: fast.tr('phone'),
              hint: '06 12 34 56 78',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return fast.tr('err_phone_required');
                }
                return null;
              },
            ),
            SizedBox(height: 20),
            if (widget.initialRole == 'LIVREUR') ...[
              Text(
                fast.tr('availability_mode'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.fast.t1,
                ),
              ),
              SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'OCCASIONAL',
                    icon: Icon(Icons.flash_on_outlined),
                    label: Text(fast.tr('occasional')),
                  ),
                  ButtonSegment(
                    value: 'PERMANENT',
                    icon: Icon(Icons.calendar_month_outlined),
                    label: Text(fast.tr('permanent')),
                  ),
                ],
                selected: {_driverType},
                onSelectionChanged: (selection) =>
                    setState(() => _driverType = selection.first),
                showSelectedIcon: false,
                style: ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(0, 48)),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? context.fast.bg
                        : context.fast.t1,
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? Color(0xFFF59E0B)
                        : context.fast.card,
                  ),
                ),
              ),
              SizedBox(height: 8),
              Text(
                fast.tr(
                  _driverType == 'OCCASIONAL'
                      ? 'occasional_desc'
                      : 'permanent_desc',
                ),
                style: TextStyle(
                  color: context.fast.t2,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
            ],
            _buildTextField(
              controller: _registerPassword,
              label: fast.tr('password'),
              hint: '••••••••',
              icon: Icons.lock_outlined,
              obscureText: _obscureRegisterPwd,
              suffix: IconButton(
                icon: Icon(
                  _obscureRegisterPwd ? Icons.visibility_off : Icons.visibility,
                  color: context.fast.t3,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureRegisterPwd = !_obscureRegisterPwd),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return fast.tr('err_pwd_required');
                if (v.length < 8) return fast.tr('err_pwd_min');
                if (!v.contains(RegExp(r'[A-Z]'))) {
                  return fast.tr('err_pwd_upper');
                }
                if (!v.contains(RegExp(r'[0-9]'))) {
                  return fast.tr('err_pwd_digit');
                }
                return null;
              },
            ),
            SizedBox(height: 32),
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.error != null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      auth.error!,
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                return ElevatedButton(
                  onPressed: auth.isBusy
                      ? null
                      : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFF59E0B),
                    foregroundColor: FASTBrand.onAmber,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: auth.isBusy
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: FASTBrand.onAmber,
                          ),
                        )
                      : Text(
                          fast.tr('register_btn'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                );
              },
            ),
            _buildGoogleButton(),
          ],
        ),
      ),
    );
  }

  /// Languages commonly spoken in FAST restaurants — picked at signup.
  static const List<(String, String)> _languages = [
    ('fr', '🇫🇷  Français'),
    ('en', '🇬🇧  English'),
    ('tr', '🇹🇷  Türkçe'),
    ('ar', '🇸🇦  العربية'),
    ('hi', '🇮🇳  हिन्दी'),
    ('bn', '🇧🇩  বাংলা'),
    ('ur', '🇵🇰  اردو'),
    ('bm', '🇲🇱  Bambara'),
    ('wo', '🇸🇳  Wolof'),
    ('ln', '🇨🇩  Lingala'),
    ('es', '🇪🇸  Español'),
    ('pt', '🇵🇹  Português'),
    ('it', '🇮🇹  Italiano'),
    ('zh', '🇨🇳  中文'),
  ];

  Widget _buildLanguagePicker() {
    final fast = context.watch<FASTProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fast.tr('lang_label'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.fast.t1,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: fast.appLanguage,
          dropdownColor: context.fast.card,
          style: TextStyle(color: context.fast.t1, fontSize: 14),
          icon: Icon(Icons.keyboard_arrow_down, color: context.fast.t3),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.language, color: context.fast.t3, size: 18),
            filled: true,
            fillColor: context.fast.card,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.fast.line, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFFF59E0B),
                width: 1.5,
              ),
            ),
          ),
          items: _languages
              .map((l) => DropdownMenuItem(value: l.$1, child: Text(l.$2)))
              .toList(),
          onChanged: (v) => fast.setAppLanguage(v ?? 'fr'),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.fast.t1,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(color: context.fast.t1, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: context.fast.faint, fontSize: 14),
            prefixIcon: Icon(icon, color: context.fast.t3, size: 18),
            suffixIcon: suffix,
            filled: true,
            fillColor: context.fast.card,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.fast.line, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFFF59E0B),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFFEF4444),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
