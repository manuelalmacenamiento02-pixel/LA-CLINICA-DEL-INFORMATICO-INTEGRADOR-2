import { Component, inject } from '@angular/core';
import { ActivatedRoute } from '@angular/router';

@Component({
  selector: 'app-module-placeholder',
  standalone: true,
  templateUrl: './module-placeholder.component.html',
})
export class ModulePlaceholderComponent {
  protected readonly title = inject(ActivatedRoute).snapshot.data['title'] as string;
}
