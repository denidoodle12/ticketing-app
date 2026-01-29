import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'core/themes/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/constants/api_config.dart';
import 'data/datasources/local/local_storage.dart';
import 'features/auth/datasources/auth_mock_datasource.dart';
import 'features/auth/datasources/auth_remote_datasource.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/tickets/datasources/ticket_remote_datasource.dart';
import 'features/tickets/datasources/ticket_mock_datasource.dart';
import 'features/tickets/repositories/ticket_repository.dart';
import 'providers/auth_provider.dart';
import 'providers/ticket_provider.dart';
import 'providers/profile_provider.dart';
import 'features/profile/datasources/profile_remote_datasource.dart';
import 'features/profile/repositories/profile_repository.dart';
import 'routes/app_routes.dart';
import 'shared/widgets/connectivity_wrapper.dart';

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  final FlutterSecureStorage secureStorage;

  const MyApp({
    super.key,
    required this.prefs,
    required this.secureStorage,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Provide LocalStorage
        Provider<LocalStorage>(
          create: (_) => LocalStorage(secureStorage, prefs),
        ),

        // Provide AuthRepository
        Provider<AuthRepository>(
          create: (context) => AuthRepositoryImpl(
            remoteDatasource: ApiConfig.useMockData ? null : AuthRemoteDatasource(),
            mockDatasource: ApiConfig.useMockData ? AuthMockDatasource() : null,
            localStorage: context.read<LocalStorage>(),
          ),
        ),

        // Provide AuthProvider
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            context.read<AuthRepository>(),
          ),
        ),

        // Provide TicketRepository
        Provider<TicketRepository>(
          create: (context) => TicketRepository(
            remoteDatasource: ApiConfig.useMockData ? null : TicketRemoteDatasource(),
            mockDatasource: ApiConfig.useMockData ? TicketMockDatasource() : null,
          ),
        ),

        // Provide TicketProvider
        ChangeNotifierProvider<TicketProvider>(
          create: (context) => TicketProvider(
            context.read<TicketRepository>(),
          ),
        ),

        // Provide ProfileRepository
        Provider<ProfileRepository>(
          create: (context) => ProfileRepositoryImpl(
            remoteDatasource: ProfileRemoteDatasource(),
          ),
        ),

        // Provide ProfileProvider
        ChangeNotifierProvider<ProfileProvider>(
          create: (context) => ProfileProvider(
            context.read<ProfileRepository>(),
          ),
        ),
      ],
      child: ToastificationWrapper(
        child: MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          routerConfig: AppRoutes.router,
          builder: (context, child) {
            return ConnectivityWrapper(
              child: child ?? const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }
}
