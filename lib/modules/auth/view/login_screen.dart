import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/size_config.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../controller/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final success = await authController.login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (success && mounted) {
        context.go('/home');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authController.errorMessage ?? 'Login failed'),
            backgroundColor: AppColors.priorityHigh,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 850;
    final cardWidth = isDesktop
        ? 900.0
        : (screenWidth - 48).clamp(280.0, 450.0);
    final authController = Provider.of<AuthController>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF040814), Color(0xFF07142A), Color(0xFF0A1F3D)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 24)),
              child: GlassContainer(
                width: cardWidth,
                borderRadius: SizeConfig.scaleWidth(context, 20),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left Side: Brand Panel (Desktop Only)
                      if (isDesktop)
                        Expanded(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: AppColors.brandGradient,
                            ),
                            padding: EdgeInsets.all(
                              SizeConfig.scaleWidth(context, 40),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(
                                    SizeConfig.scaleWidth(context, 12),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(
                                      SizeConfig.scaleWidth(context, 16),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.movie_filter,
                                    color: Colors.white,
                                    size: SizeConfig.iconSize(context, 40),
                                  ),
                                ),
                                SizedBox(
                                  height: SizeConfig.scaleHeight(context, 24),
                                ),
                                Text(
                                  'VfxPick\nPipeline Tracker',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: SizeConfig.fontSize(context, 32),
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                SizedBox(
                                  height: SizeConfig.scaleHeight(context, 16),
                                ),
                                Text(
                                  'Manage shots, assets, tasks, and reviews in one unified premium studio console. Experience state-of-the-art VFX pipeline workflow.',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: SizeConfig.fontSize(context, 14),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Right Side: Input Form
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(
                            isDesktop
                                ? SizeConfig.scaleWidth(context, 40)
                                : SizeConfig.scaleWidth(context, 24),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Welcome Back',
                                  style: TextStyle(
                                    fontSize: SizeConfig.fontSize(context, 24),
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(
                                  height: SizeConfig.scaleHeight(context, 4),
                                ),
                                Text(
                                  'Sign in to access your production tracker',
                                  style: TextStyle(
                                    fontSize: SizeConfig.fontSize(context, 14),
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.color,
                                  ),
                                ),
                                SizedBox(
                                  height: SizeConfig.scaleHeight(context, 24),
                                ),

                                // Email
                                CustomTextField(
                                  controller: _emailController,
                                  labelText: 'EMAIL ADDRESS',
                                  hintText: 'Enter your studio email',
                                  prefixIcon: Icons.email_outlined,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(
                                  height: SizeConfig.scaleHeight(context, 16),
                                ),

                                // Password
                                CustomTextField(
                                  controller: _passwordController,
                                  labelText: 'PASSWORD',
                                  hintText: 'Enter password',
                                  prefixIcon: Icons.lock_outline,
                                  isPassword: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(
                                  height: SizeConfig.scaleHeight(context, 16),
                                ),

                                // Remember Me & Forgot Password Row
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  runSpacing: SizeConfig.scaleHeight(
                                    context,
                                    4,
                                  ),
                                  spacing: SizeConfig.scaleWidth(context, 10),
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: authController.rememberMe,
                                          onChanged: (val) {
                                            authController.toggleRememberMe(
                                              val ?? false,
                                            );
                                          },
                                          activeColor: AppColors.brandGreen,
                                        ),
                                        Text(
                                          'Remember Me',
                                          style: TextStyle(
                                            fontSize: SizeConfig.fontSize(
                                              context,
                                              13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Password reset link has been sent to your registered email.',
                                            ),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          fontSize: SizeConfig.fontSize(
                                            context,
                                            13,
                                          ),
                                          color: AppColors.brandGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: SizeConfig.scaleHeight(context, 20),
                                ),

                                // Sign In Button
                                GradientButton(
                                  text: 'SIGN IN',
                                  width: double.infinity,
                                  isLoading: authController.isLoading,
                                  onPressed: _handleLogin,
                                ),
                                SizedBox(
                                  height: SizeConfig.scaleHeight(context, 16),
                                ),

                                // Signup is intentionally hidden from the login page.
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
