import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/app_const.dart';
import 'package:opennutritracker/core/presentation/widgets/dynamic_ont_logo.dart';

class HomeAppbar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppbar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          const SizedBox(width: 40, child: DynamicOntLogo()),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: AppConst.appName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
