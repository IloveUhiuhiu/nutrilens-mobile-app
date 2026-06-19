import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/di/app_dependencies.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/food_scan/presentation/bloc/food_scan_bloc.dart';
import 'features/meal_history/presentation/bloc/meal_history_cubit.dart';
import 'features/nutrition/presentation/bloc/nutrition_cubit.dart';
import 'features/profile/presentation/bloc/profile_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const NutriLensApp());
}

class NutriLensApp extends StatelessWidget {
  const NutriLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => AuthBloc(
            loginUseCase: AppDependencies.loginUseCase,
            registerUseCase: AppDependencies.registerUseCase,
            authRepository: AppDependencies.authRepository,
          ),
        ),
        BlocProvider(
          create: (_) => FoodScanBloc(
            repository: AppDependencies.foodScanRepository,
          ),
        ),
        BlocProvider(
          create: (_) => NutritionCubit(AppDependencies.nutritionRepository),
        ),
        BlocProvider(
          create: (_) =>
              MealHistoryCubit(AppDependencies.mealHistoryRepository),
        ),
        BlocProvider(
          create: (_) => ProfileCubit(AppDependencies.profileRepository),
        ),
      ],
      child: MaterialApp.router(
        title: 'NutriLens',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: AppRouter.router,
      ),
    );
  }
}
