export type ListType = 'shopping' | 'packing';

export interface List {
  id: string;
  type: ListType;
  name: string;
  archived: boolean;
  familyId: string;
}

export interface ListItem {
  id: string;
  listId: string;
  name: string;
  checked: boolean;
  position: number;
  addedById: string;
}
