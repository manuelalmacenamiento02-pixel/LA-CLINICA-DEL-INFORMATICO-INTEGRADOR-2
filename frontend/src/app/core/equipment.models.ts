export const EQUIPMENT_TYPES = ['Laptop', 'PC', 'Impresora', 'Monitor', 'Tablet', 'Otro'] as const;

export type EquipmentType = (typeof EQUIPMENT_TYPES)[number];

export interface Equipment {
  id: string;
  clientId: string;
  type: EquipmentType;
  brand: string;
  model: string;
  serialNumber: string;
  characteristics: string;
  accessories: string;
  observations: string;
}

export type EquipmentDraft = Omit<Equipment, 'id'>;
