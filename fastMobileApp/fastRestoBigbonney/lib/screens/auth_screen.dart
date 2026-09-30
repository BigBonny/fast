import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../provider.dart';
import '../resto_provider.dart';
import '../main.dart';
import 'resto/onboarding_screen.dart';
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
    final isLivreur = auth.isLivreur;

    // Load data from API after auth
    fastProv.loadFromApi();

    if (isResto) {
      // Sync resto provider
      final restoProv = context.read<RestoProvider>();
      final restoId = user.restaurant?['id'] as String?;
      restoProv.loadFromApi(restaurantId: restoId);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            isResto
                ? const OnboardingScreen()
                : isLivreur
                    ? const DriverShell()
                    : const MainShell(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                );
              }
            },
          ),
          title: Text(
            _showRestoFields
                ? 'Espace Fast Pro'
                : widget.initialRole == 'LIVREUR'
                    ? 'Espace Livreur'
                    : 'Espace Client',
            style: TextStyle(color: context.fast.t1, fontWeight: FontWeight.bold),
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
                      fontWeight: FontWeight.bold, fontSize: 15),
                  unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                  tabs: const [
                    Tab(text: 'Connexion'),
                    Tab(text: 'Inscription'),
                  ],
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLoginForm(),
                      _buildRegisterForm(),
                    ],
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
    return Form(
      key: _loginFormKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(
              controller: _loginEmail,
              label: 'Email',
              hint: 'adresse@exemple.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email requis';
                if (!v.contains('@')) return 'Email invalide';
                return null;
              },
            ),
                  SizedBox(height: 20),
            _buildTextField(
              controller: _loginPassword,
              label: 'Mot de passe',
              hint: '••••••••',
              icon: Icons.lock_outlined,
              obscureText: _obscureLoginPwd,
              suffix: IconButton(
                icon: Icon(
                  _obscureLoginPwd
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: context.fast.t3,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureLoginPwd = !_obscureLoginPwd),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Mot de passe requis';
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
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
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
                  onPressed: auth.state == AuthState.loading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFF59E0B),
                    foregroundColor: FASTBrand.onAmber,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: auth.state == AuthState.loading
                      ?       SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: FASTBrand.onAmber,
                          ),
                        )
                      : const Text(
                          'Se connecter',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                );
              },
            ),
            if (widget.initialRole != 'RESTAURANT' && widget.initialRole != 'LIVREUR')
              _buildGoogleButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Divider(color: context.fast.line)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('ou', style: TextStyle(color: context.fast.t3, fontSize: 12)),
              ),
              Expanded(child: Divider(color: context.fast.line)),
            ],
          ),
          const SizedBox(height: 16),
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              return OutlinedButton(
                onPressed: auth.state == AuthState.loading
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
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Continuer avec Google',
                      style: TextStyle(color: context.fast.t1, fontWeight: FontWeight.bold, fontSize: 14),
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
    return Form(
      key: _registerFormKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(
              controller: _registerName,
              label: 'Nom complet',
              hint: 'Jean Dupont',
              icon: Icons.person_outlined,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Nom requis';
                return null;
              },
            ),
                  SizedBox(height: 20),
            _buildTextField(
              controller: _registerEmail,
              label: 'Email',
              hint: 'adresse@exemple.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email requis';
                if (!v.contains('@')) return 'Email invalide';
                return null;
              },
            ),
                  SizedBox(height: 20),
            _buildTextField(
              controller: _registerPhone,
              label: 'Téléphone',
              hint: '06 12 34 56 78',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Téléphone requis';
                return null;
              },
            ),
                  SizedBox(height: 20),
            if (widget.initialRole == 'LIVREUR') ...[ Text(
                'Mode de disponibilité',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.fast.t1),
              ),
                    SizedBox(height: 8),
              SegmentedButton<String>(
                segments:       [
                  ButtonSegment(
                    value: 'OCCASIONAL',
                    icon: Icon(Icons.flash_on_outlined),
                    label: Text('Occasionnel'),
                  ),
                  ButtonSegment(
                    value: 'PERMANENT',
                    icon: Icon(Icons.calendar_month_outlined),
                    label: Text('Permanent'),
                  ),
                ],
                selected: {_driverType},
                onSelectionChanged: (selection) => setState(() => _driverType = selection.first),
                showSelectedIcon: false,
                style: ButtonStyle(
                  minimumSize:       WidgetStatePropertyAll(Size(0, 48)),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? context.fast.bg
                        : context.fast.t1,
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ?       Color(0xFFF59E0B)
                        : context.fast.card,
                  ),
                ),
              ),
                    SizedBox(height: 8), Text(
                _driverType == 'OCCASIONAL'
                    ? 'Connectez-vous librement lorsque vous souhaitez livrer.'
                    : 'Définissez des créneaux réguliers et mettez-les en pause si besoin.',
                style: TextStyle(color: context.fast.t2, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 20),
            ],
            _buildTextField(
              controller: _registerPassword,
              label: 'Mot de passe',
              hint: '••••••••',
              icon: Icons.lock_outlined,
              obscureText: _obscureRegisterPwd,
              suffix: IconButton(
                icon: Icon(
                  _obscureRegisterPwd
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: context.fast.t3,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureRegisterPwd = !_obscureRegisterPwd),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Mot de passe requis';
                if (v.length < 8) return 'Minimum 8 caractères';
                if (!v.contains(RegExp(r'[A-Z]'))) return 'Doit contenir une majuscule';
                if (!v.contains(RegExp(r'[0-9]'))) return 'Doit contenir un chiffre';
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
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
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
                  onPressed:
                      auth.state == AuthState.loading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFF59E0B),
                    foregroundColor: FASTBrand.onAmber,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: auth.state == AuthState.loading
                      ?       SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: FASTBrand.onAmber,
                          ),
                        )
                      : const Text(
                          'Créer mon compte',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon, TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [ Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.fast.t1,
          ),
        ),
              SizedBox(height: 8), TextFormField(
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
              borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
