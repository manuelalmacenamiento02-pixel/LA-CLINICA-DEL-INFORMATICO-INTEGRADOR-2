import { ApiStore } from '../../core/api.store';
import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../../core/auth.service';
import { IconComponent } from '../../shared/icon/icon.component';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [FormsModule, IconComponent, RouterLink],
  templateUrl: './login.component.html',
})
export class LoginComponent {
  protected readonly busy = inject(ApiStore).pending;
  protected username = '';
  protected password = '';
  protected errorMessage = '';
  protected passwordVisible = false;
  protected submitted = false;

  private readonly router = inject(Router);
  private readonly authService = inject(AuthService);

  protected async signIn(): Promise<void> {
    if (this.busy()) return;
    this.submitted = true;
    if (!this.username.trim() || !this.password) {
      this.errorMessage = 'Ingresa tu usuario y contraseña para continuar.';
      return;
    }

    const result = await this.authService.signIn(this.username, this.password);
    if (result !== 'success') {
      this.errorMessage =
        result === 'inactive-user'
          ? 'Este usuario está desactivado. Contacta al administrador.'
          : result === 'storage-error'
            ? 'No se pudo conectar con el servidor. Comprueba que esté en ejecución.'
            : 'El usuario o la contraseña son incorrectos.';
      return;
    }

    this.errorMessage = '';
    void this.router.navigateByUrl('/dashboard');
  }
}
