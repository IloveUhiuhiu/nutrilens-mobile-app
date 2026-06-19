import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/register_usecase.dart';
import '../../features/food_scan/data/datasources/food_scan_remote_datasource.dart';
import '../../features/food_scan/data/repositories/food_scan_repository_impl.dart';
import '../../features/food_scan/domain/repositories/food_scan_repository.dart';
import '../../features/meal_detail/data/repositories/meal_detail_repository.dart';
import '../../features/meal_history/data/repositories/meal_history_repository.dart';
import '../../features/nutrition/data/repositories/nutrition_repository.dart';
import '../../features/profile/data/repositories/profile_repository.dart';
import '../../features/search/data/repositories/meal_search_repository.dart';
import '../network/dio_client.dart';
import '../router/app_router.dart';
import '../storage/secure_token_storage.dart';

class AppDependencies {
  AppDependencies._();

  static final SecureTokenStorage tokenStorage = SecureTokenStorage();
  static final DioClient dioClient = DioClient(
    tokenStorage: tokenStorage,
    onUnauthorized: () => AppRouter.router.go('/login'),
  );

  static final AuthRemoteDataSource authRemoteDataSource =
      AuthRemoteDataSourceImpl(dioClient);
  static final AuthRepository authRepository = AuthRepositoryImpl(
    authRemoteDataSource,
    tokenStorage,
  );
  static final LoginUseCase loginUseCase = LoginUseCase(authRepository);
  static final RegisterUseCase registerUseCase = RegisterUseCase(
    authRepository,
  );

  static final FoodScanRemoteDataSource foodScanRemoteDataSource =
      FoodScanRemoteDataSourceImpl(dioClient);
  static final FoodScanRepository foodScanRepository =
      FoodScanRepositoryImpl(foodScanRemoteDataSource);

  static final NutritionRepository nutritionRepository = NutritionRepository(
    dioClient,
  );
  static final MealHistoryRepository mealHistoryRepository =
      MealHistoryRepository(dioClient);
  static final ProfileRepository profileRepository = ProfileRepository(
    dioClient,
  );
  static final MealSearchRepository mealSearchRepository = MealSearchRepository(
    dioClient,
  );
  static final MealDetailRepository mealDetailRepository = MealDetailRepository(
    dioClient,
  );
}
