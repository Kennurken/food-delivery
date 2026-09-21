import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/motion.dart';
import '../../../core/widgets/animated_gradient.dart';
import '../../../core/widgets/pressable.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(text: 'user@food.dev');
  final _password = TextEditingController(text: 'user123');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .login(_email.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    ref.listen(authControllerProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(next.error!))));
      }
    });

    final fields = <Widget>[
      Center(
        child:
            Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.35),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.delivery_dining,
                    size: 46,
                    color: scheme.onPrimary,
                  ),
                )
                .animate()
                .scale(
                  begin: const Offset(0.6, 0.6),
                  duration: Motion.slow,
                  curve: Motion.pop,
                )
                .fadeIn(),
      ),
      const SizedBox(height: 20),
      Text(
        'Food Delivery',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      Text(
        'Hot food, fast.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
      const SizedBox(height: 36),
      TextFormField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Email',
          prefixIcon: Icon(Icons.alternate_email),
        ),
        validator: (v) => v != null && v.contains('@') ? null : 'Invalid email',
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _password,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'Password',
          prefixIcon: Icon(Icons.lock_outline),
        ),
        validator: (v) => v != null && v.length >= 6 ? null : 'Min 6 chars',
        onFieldSubmitted: (_) => _submit(),
      ),
      const SizedBox(height: 24),
      Pressable(
        onTap: auth.isLoading ? null : _submit,
        child: FilledButton(
          onPressed: auth.isLoading ? null : _submit,
          child: AnimatedSwitcher(
            duration: Motion.fast,
            child: auth.isLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign in'),
          ),
        ),
      ),
      TextButton(
        onPressed: () => context.push('/register'),
        child: const Text('Create account'),
      ),
      if (kDebugMode) ...[
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            for (final (label, email, pass) in const [
              ('User', 'user@food.dev', 'user123'),
              ('Courier', 'courier@food.dev', 'courier123'),
              ('Admin', 'admin@food.dev', 'admin123'),
            ])
              ActionChip(
                label: Text(label),
                onPressed: () {
                  _email.text = email;
                  _password.text = pass;
                  _submit();
                },
              ),
          ],
        ),
      ],
    ];

    return Scaffold(
      body: AnimatedGradient(
        colors: [scheme.primary, scheme.tertiary, scheme.primaryContainer],
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: fields
                      .animate(interval: Motion.stagger)
                      .fadeIn(duration: Motion.normal, curve: Motion.enter)
                      .slideY(
                        begin: 0.12,
                        end: 0,
                        duration: Motion.normal,
                        curve: Motion.enter,
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
