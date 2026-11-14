import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from './auth.service';
import { Permission } from './user.models';
import { PermissionsService } from './permissions.service';

export const authGuard: CanActivateFn = (_route, state) => {
  const authService = inject(AuthService);
  const router = inject(Router);
  return authService.hasSession()
    ? true
    : router.createUrlTree(['/login'], { queryParams: { returnUrl: state.url } });
};

export const guestGuard: CanActivateFn = () => {
  const authService = inject(AuthService);
  const router = inject(Router);
  return authService.hasSession() ? router.createUrlTree(['/dashboard']) : true;
};

export const permissionGuard: CanActivateFn = (route) => {
  const authService = inject(AuthService);
  const permissionsService = inject(PermissionsService);
  const router = inject(Router);
  const permission = route.data['permission'] as Permission | undefined;
  const user = authService.currentUser();

  return user && (!permission || permissionsService.can(user.role, permission))
    ? true
    : router.createUrlTree(['/dashboard']);
};
