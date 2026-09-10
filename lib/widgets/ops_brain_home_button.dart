import 'package:flutter/material.dart';

import '../services/portal_sign_in.dart';

class OpsBrainHomeButton extends StatelessWidget {
  const OpsBrainHomeButton({super.key});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Open OpsBrain Home in a new tab',
        child: TextButton.icon(
          onPressed: () => openPortalSignIn(opsBrainHomeUrl(Uri.base)),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          ),
          icon: const Icon(Icons.home_outlined, size: 20),
          label: const Text('OpsBrain Home'),
        ),
      );
}
